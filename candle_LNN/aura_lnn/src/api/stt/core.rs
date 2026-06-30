use super::model::{model_paths, resolve_model_dir, runtime_cache_dir};
use super::vad;
use anyhow::Result;
use once_cell::sync::OnceCell;
use sherpa_onnx::{OnlineRecognizer, OnlineRecognizerConfig, OnlineStream};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;

static STT_ENGINE: OnceCell<Mutex<OnlineRecognizer>> = OnceCell::new();
static STT_STREAM: OnceCell<Mutex<OnlineStream>> = OnceCell::new();
static STT_TOTAL_SAMPLES: AtomicU64 = AtomicU64::new(0);
static STT_DECODE_TOTAL: AtomicU64 = AtomicU64::new(0);
// Text committed at prior endpoints during the current utterance. get_result()
// returns only the RUNNING (post-reset) hypothesis, so without accumulating
// it here an endpoint that fires mid-utterance would discard everything
// decoded before it — exactly the "hears speech, emits empty text" symptom.
// This mirrors stt_diag.rs's `accumulated` buffer (which decodes correctly).
static STT_COMMITTED: OnceCell<Mutex<String>> = OnceCell::new();

fn epoch_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

pub(super) fn init() -> bool {
    if STT_ENGINE.get().is_some() {
        return true;
    }

    let (dir, used_int8) = match resolve_model_dir() {
        Some(hit) => hit,
        None => {
            let cache_hint = runtime_cache_dir()
                .map(|d| d.display().to_string())
                .unwrap_or_else(|| "<no XDG_DATA_HOME/HOME>".to_string());
            eprintln!(
                "[AURA_STT] No streaming-Zipformer model found. Expected the int8 set at \
                 {cache_hint} (downloaded on first launch) or under MODEL_DIR. STT stays \
                 unavailable; the Dart side falls back to whisper."
            );
            return false;
        }
    };

    let (enc, dec, joi, tok) = model_paths(&dir, used_int8);

    let mut config = OnlineRecognizerConfig::default();
    config.model_config.transducer.encoder = Some(enc.to_string_lossy().to_string());
    config.model_config.transducer.decoder = Some(dec.to_string_lossy().to_string());
    config.model_config.transducer.joiner = Some(joi.to_string_lossy().to_string());
    config.model_config.tokens = Some(tok.to_string_lossy().to_string());
    config.model_config.num_threads = 2;
    config.model_config.provider = Some("cpu".to_string());
    config.decoding_method = Some("greedy_search".to_string());

    // Endpointing. rule1 fires after ~2s of trailing silence, rule2 is a
    // shorter intra-utterance breath pause, rule3 caps an utterance at 20s.
    config.enable_endpoint = true;
    config.rule1_min_trailing_silence = 2.0;
    config.rule2_min_trailing_silence = 1.2;
    config.rule3_min_utterance_length = 20.0;

    match OnlineRecognizer::create(&config) {
        Some(recognizer) => {
            let stream = recognizer.create_stream();
            eprintln!(
                "[AURA_STT] Streaming STT initialized ({}) from {}",
                if used_int8 { "int8" } else { "full" },
                dir.display(),
            );
            let _ = STT_ENGINE.set(Mutex::new(recognizer));
            let _ = STT_STREAM.set(Mutex::new(stream));
            let _ = STT_COMMITTED.set(Mutex::new(String::new()));
            vad::init_buffer();
            true
        }
        None => {
            eprintln!("[AURA_STT_ERR] Failed to create Online STT recognizer");
            false
        }
    }
}

pub(super) fn push_audio(samples: Vec<f32>, sample_rate: i32) -> Result<String> {
    if let (Some(recognizer_mutex), Some(stream_mutex)) = (STT_ENGINE.get(), STT_STREAM.get()) {
        let recognizer = recognizer_mutex.lock().unwrap();
        let stream = stream_mutex.lock().unwrap();

        let n_samples = samples.len();
        let total =
            STT_TOTAL_SAMPLES.fetch_add(n_samples as u64, Ordering::Relaxed) + n_samples as u64;

        let rms = vad::rms_energy(&samples);
        let samples_to_push = match vad::gate_audio(samples, sample_rate) {
            Some(s) => s,
            None => return Ok(String::new()),
        };
        stream.accept_waveform(sample_rate, &samples_to_push);

        let mut decode_iters = 0u32;
        while recognizer.is_ready(&stream) {
            recognizer.decode(&stream);
            decode_iters += 1;
        }
        let dec_total = if decode_iters > 0 {
            STT_DECODE_TOTAL.fetch_add(decode_iters as u64, Ordering::Relaxed) + decode_iters as u64
        } else {
            STT_DECODE_TOTAL.load(Ordering::Relaxed)
        };

        let mut result_text = String::new();
        if let Some(res) = recognizer.get_result(&stream) {
            result_text = res.text;
        }

        let is_ep = recognizer.is_endpoint(&stream);

        if is_ep {
            if !result_text.trim().is_empty() {
                if let Some(committed_cell) = STT_COMMITTED.get() {
                    if let Ok(mut committed) = committed_cell.lock() {
                        if !committed.is_empty() {
                            committed.push(' ');
                        }
                        committed.push_str(result_text.trim());
                    }
                }
            }
            recognizer.reset(&stream);
            result_text.clear();
            vad::reset();
        }

        let mut full_text = String::new();
        if let Some(committed_cell) = STT_COMMITTED.get() {
            if let Ok(committed) = committed_cell.lock() {
                full_text.push_str(&committed);
            }
        }
        if !result_text.is_empty() {
            if !full_text.is_empty() && !full_text.ends_with(' ') {
                full_text.push(' ');
            }
            full_text.push_str(result_text.trim());
        }

        static STT_DBG_LAST_MS: std::sync::atomic::AtomicI64 = std::sync::atomic::AtomicI64::new(0);
        let now_ms = epoch_millis();
        let last_ms = STT_DBG_LAST_MS.load(Ordering::Relaxed);
        let interesting = !full_text.is_empty() || is_ep;
        let due = now_ms.wrapping_sub(last_ms) >= 2000;
        if interesting || due {
            if due || interesting {
                STT_DBG_LAST_MS.store(now_ms, Ordering::Relaxed);
            }
            eprintln!(
                "[AURA_STT_DBG] push: {} samples ({:.0}ms), total={}, decode_iters={}, dec_total={}, rms={:.4}, text=\"{}\", endpoint={}, sr={}",
                n_samples,
                (n_samples as f32 / sample_rate as f32) * 1000.0,
                total,
                decode_iters,
                dec_total,
                rms,
                full_text,
                is_ep,
                sample_rate,
            );
        }

        Ok(full_text)
    } else {
        Err(anyhow::anyhow!("STT engine not initialized"))
    }
}

pub(super) fn available() -> bool {
    STT_ENGINE.get().is_some()
}

pub(super) fn reset_session() {
    if let Some(cell) = STT_COMMITTED.get() {
        if let Ok(mut committed) = cell.lock() {
            committed.clear();
        }
    }
    if let (Some(recognizer_mutex), Some(stream_mutex)) = (STT_ENGINE.get(), STT_STREAM.get()) {
        if let (Ok(recognizer), Ok(stream)) = (recognizer_mutex.lock(), stream_mutex.lock()) {
            recognizer.reset(&stream);
        }
    }
    vad::reset();
}

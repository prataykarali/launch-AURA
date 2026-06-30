use super::audio::{
    append_pause, init_audio_thread, punctuation_pause_ms, store_volume, volume, AudioMsg,
};
use super::model::{find_file, find_voice_model};
use super::online::try_online_tts;
use super::TtsAudio;
use anyhow::Result;
use once_cell::sync::{Lazy, OnceCell};
use sherpa_onnx::{
    GenerationConfig, OfflineTts, OfflineTtsConfig, OfflineTtsModelConfig,
    OfflineTtsVitsModelConfig,
};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering, Ordering as AtomicOrdering};
use std::sync::{mpsc, Mutex};
use std::time::{Duration, Instant};

static TTS_ENGINE: OnceCell<Mutex<OfflineTts>> = OnceCell::new();
static AUDIO_TX: OnceCell<mpsc::Sender<AudioMsg>> = OnceCell::new();
static TTS_TX: OnceCell<mpsc::Sender<TtsJob>> = OnceCell::new();
static TTS_INIT_ATTEMPTED: AtomicBool = AtomicBool::new(false);
static TTS_EPOCH: AtomicU64 = AtomicU64::new(0);

// Anti-spam: suppress duplicate TTS requests for the same text within a short
// window. The Flutter side already deduplicates, but guarding here too protects
// against FFI callers, multiple surfaces, and rapid platform events.
static LAST_SPOKEN: Lazy<Mutex<(String, Instant)>> =
    Lazy::new(|| Mutex::new((String::new(), Instant::now() - Duration::from_secs(10))));
const DEDUP_WINDOW_MS: u64 = 2_000;

struct TtsJob {
    text: String,
    speed: f32,
    epoch: u64,
}

pub(super) fn init() -> bool {
    if available() {
        return true;
    }

    TTS_INIT_ATTEMPTED.store(true, Ordering::Relaxed);
    // Sherpa-onnx TTS is now ON by default. OfflineTts::create() can
    // segfault in the C++ ONNX layer (uncatchable by Rust), so a kill-switch
    // env var is honored for emergencies. init() is otherwise graceful: on
    // any failure it returns false and the Dart side falls back to text-only.
    if std::env::var("AURA_DISABLE_SHERPA_TTS").ok().as_deref() == Some("1") {
        eprintln!("[AURA_TTS] Sherpa-onnx TTS disabled by AURA_DISABLE_SHERPA_TTS=1.");
        return false;
    }

    let dir = super::model::resolve_tts_dir();

    let model_path = match find_voice_model() {
        Some(p) => p,
        None => return false,
    };
    eprintln!("[AURA_TTS] Using voice model: {:?}", model_path);
    let tokens_path = match find_file(&dir, "tokens.txt") {
        Some(p) => p,
        None => {
            eprintln!("[AURA_TTS_ERR] tokens.txt not found in any search path, searched: {:?}, {:?}, {:?}", dir.join("tokens.txt"), dir.join("piper/tokens.txt"), dir.parent().map(|p| p.join("piper/tokens.txt")));
            dir.join("piper/tokens.txt")
        }
    };

    let data_dir = match find_file(&dir, "espeak-ng-data") {
        Some(p) => p,
        None => {
            eprintln!("[AURA_TTS_ERR] espeak-ng-data not found in any search path, searched: {:?}, {:?}, {:?}", dir.join("espeak-ng-data"), dir.join("piper/espeak-ng-data"), dir.parent().map(|p| p.join("piper/espeak-ng-data")));
            dir.join("piper/espeak-ng-data")
        }
    };

    if !tokens_path.exists() {
        eprintln!("[AURA_TTS_ERR] tokens.txt not found at {:?}", tokens_path);
        return false;
    }
    if !data_dir.exists() {
        eprintln!("[AURA_TTS_ERR] espeak-ng-data not found at {:?}", data_dir);
        return false;
    }

    let vits_config = OfflineTtsVitsModelConfig {
        model: Some(model_path.to_string_lossy().to_string()),
        lexicon: None,
        tokens: Some(tokens_path.to_string_lossy().to_string()),
        data_dir: Some(data_dir.to_string_lossy().to_string()),
        // Fix Linux TTS voice instability: zero-out the latent/duration noise
        // scales so the same text always produces the same waveform.
        noise_scale: 0.0,
        noise_scale_w: 0.0,
        length_scale: 1.1,
        dict_dir: None,
    };

    let model_config = OfflineTtsModelConfig {
        vits: vits_config,
        num_threads: 2,
        debug: false,
        ..Default::default()
    };

    let config = OfflineTtsConfig {
        model: model_config,
        ..Default::default()
    };

    if AUDIO_TX.get().is_none() {
        let Some(tx) = init_audio_thread() else {
            return false;
        };
        let _ = AUDIO_TX.set(tx);
    }

    match OfflineTts::create(&config) {
        Some(tts) => {
            let _ = TTS_ENGINE.set(Mutex::new(tts));
            eprintln!(
                "[AURA_TTS] Sherpa-onnx TTS initialized from {:?}",
                model_path
            );

            if let Some(atx) = AUDIO_TX.get() {
                let _ = atx.send(AudioMsg::SetVolume(volume()));
            }

            if TTS_TX.get().is_none() {
                let (tx, rx) = mpsc::channel::<TtsJob>();
                std::thread::spawn(move || {
                    while let Ok(job) = rx.recv() {
                        if job.epoch != TTS_EPOCH.load(AtomicOrdering::SeqCst) {
                            continue;
                        }
                        if let Some(tts_mutex) = TTS_ENGINE.get() {
                            let tts = tts_mutex.lock().unwrap();
                            let gen_config = GenerationConfig {
                                speed: job.speed,
                                ..Default::default()
                            };
                            if let Some(audio) = tts.generate_with_config(
                                &job.text,
                                &gen_config,
                                None::<fn(&[f32], f32) -> bool>,
                            ) {
                                let samples = audio.samples().to_vec();
                                let sample_rate = audio.sample_rate();
                                let mut samples = samples;
                                append_pause(
                                    &mut samples,
                                    sample_rate,
                                    punctuation_pause_ms(&job.text),
                                );
                                if job.epoch == TTS_EPOCH.load(AtomicOrdering::SeqCst) {
                                    if let Some(atx) = AUDIO_TX.get() {
                                        let _ = atx.send(AudioMsg::Play {
                                            samples,
                                            sample_rate: sample_rate as u32,
                                        });
                                    }
                                }
                            }
                        }
                    }
                });
                let _ = TTS_TX.set(tx);
            }

            true
        }
        None => {
            eprintln!(
                "[AURA_TTS_ERR] Failed to create Sherpa-onnx TTS with config {:?}",
                config
            );
            false
        }
    }
}

pub(super) fn speak(text: String, speed: f32, interrupt: bool) -> Result<Option<TtsAudio>> {
    if interrupt {
        stop();
    }

    // Anti-spam: suppress duplicate TTS requests for the same text within a
    // short window. The Flutter side already deduplicates, but guarding here too
    // protects against FFI callers, multiple surfaces, and rapid platform events.
    let now = Instant::now();
    {
        let mut last = LAST_SPOKEN.lock().unwrap();
        if !interrupt && last.0 == text && last.1.elapsed() < Duration::from_millis(DEDUP_WINDOW_MS)
        {
            eprintln!(
                "[AURA_TTS] Skipping duplicate TTS for {:?} within dedup window",
                text
            );
            return Ok(None);
        }
        last.0 = text.clone();
        last.1 = now;
    }

    let text_clone = text.clone();
    let epoch = TTS_EPOCH.load(AtomicOrdering::SeqCst);
    std::thread::spawn(move || {
        if epoch != TTS_EPOCH.load(AtomicOrdering::SeqCst) {
            return;
        }

        if AUDIO_TX.get().is_none() {
            if let Some(tx) = init_audio_thread() {
                let _ = AUDIO_TX.set(tx);
            }
        }

        let prefer_online = std::env::var("AURA_PREFER_ONLINE_TTS").ok().as_deref() == Some("1");

        if prefer_online {
            if let Some(path) = try_online_tts(&text_clone) {
                if epoch == TTS_EPOCH.load(AtomicOrdering::SeqCst) {
                    eprintln!("[AURA_TTS] Using online TTS (AURA_PREFER_ONLINE_TTS=1)");
                    if let Some(atx) = AUDIO_TX.get() {
                        let _ = atx.send(AudioMsg::PlayFile(path));
                    }
                }
                return;
            }
            eprintln!("[AURA_TTS] Online TTS failed; falling back to offline Rust TTS");
        }

        if TTS_TX.get().is_none() && !TTS_INIT_ATTEMPTED.load(Ordering::Relaxed) {
            eprintln!("[AURA_TTS] Auto-initializing offline Rust TTS...");
            let ok = init();
            eprintln!("[AURA_TTS] Offline auto-init result: {}", ok);
        }

        if let Some(tx) = TTS_TX.get() {
            eprintln!("[AURA_TTS] Using offline Rust TTS (sherpa)");
            let _ = tx.send(TtsJob {
                text: text_clone,
                speed,
                epoch,
            });
        }
    });

    Ok(None)
}

pub(super) fn stop() -> bool {
    TTS_EPOCH.fetch_add(1, AtomicOrdering::SeqCst);
    if let Some(tx) = AUDIO_TX.get() {
        let _ = tx.send(AudioMsg::Stop);
        true
    } else {
        false
    }
}

pub(super) fn set_volume(v: f32) {
    store_volume(v);
    if let Some(atx) = AUDIO_TX.get() {
        let _ = atx.send(AudioMsg::SetVolume(volume()));
    }
}

pub(super) fn available() -> bool {
    TTS_ENGINE.get().is_some() && AUDIO_TX.get().is_some() && TTS_TX.get().is_some()
}

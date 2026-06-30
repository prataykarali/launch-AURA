use once_cell::sync::OnceCell;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::Mutex;

// ── VAD gate: do not feed audio into the recognizer until the user is
// actually speaking. This fixes the symptom where STT "starts processing"
// (and sometimes hallucinates) during silence before the user speaks.
//
// Pre-speech audio is buffered for a short window so that the first few
// milliseconds of speech are not clipped when the gate opens.
static STT_PRE_SPEECH_BUFFER: OnceCell<Mutex<Vec<f32>>> = OnceCell::new();
static STT_SPEECH_ACTIVE: AtomicBool = AtomicBool::new(false);
static STT_VAD_CHUNK_COUNT: AtomicU32 = AtomicU32::new(0);

// RMS energy threshold for "this chunk contains speech". Tuned for 16 kHz
// microphone audio; override with AURA_STT_VAD_THRESHOLD if a mic is noisy.
const DEFAULT_VAD_RMS_THRESHOLD: f32 = 0.02;
// Keep up to 0.5 s of audio before the speech gate opens.
const VAD_PRE_BUFFER_SECS: f32 = 0.5;
// Require two consecutive chunks above the threshold before opening the gate
// to avoid false triggers from brief pops/clicks.
const VAD_REQUIRED_CHUNKS: u32 = 2;

fn vad_rms_threshold() -> f32 {
    std::env::var("AURA_STT_VAD_THRESHOLD")
        .ok()
        .and_then(|s| s.parse::<f32>().ok())
        .filter(|v| *v > 0.0)
        .unwrap_or(DEFAULT_VAD_RMS_THRESHOLD)
}

pub(super) fn rms_energy(samples: &[f32]) -> f32 {
    if samples.is_empty() {
        return 0.0;
    }
    let sum: f64 = samples.iter().map(|s| (*s as f64) * (*s as f64)).sum();
    ((sum / samples.len() as f64) as f32).sqrt()
}

pub(super) fn init_buffer() {
    let _ = STT_PRE_SPEECH_BUFFER.set(Mutex::new(Vec::new()));
    reset();
}

pub(super) fn reset() {
    STT_SPEECH_ACTIVE.store(false, Ordering::Relaxed);
    STT_VAD_CHUNK_COUNT.store(0, Ordering::Relaxed);
    if let Some(cell) = STT_PRE_SPEECH_BUFFER.get() {
        if let Ok(mut buf) = cell.lock() {
            buf.clear();
        }
    }
}

/// Returns `None` while the gate is closed (silence), keeping a rolling
/// pre-buffer. Returns `Some(samples)` when the gate opens, prepending the
/// pre-buffer so the start of the utterance is not clipped. Once the gate is
/// open, subsequent calls pass the input through.
pub(super) fn gate_audio(samples: Vec<f32>, sample_rate: i32) -> Option<Vec<f32>> {
    let rms = rms_energy(&samples);
    let mut samples_to_push = samples;

    if STT_SPEECH_ACTIVE.load(Ordering::Relaxed) {
        return Some(samples_to_push);
    }

    let threshold = vad_rms_threshold();
    if rms < threshold {
        if let Some(cell) = STT_PRE_SPEECH_BUFFER.get() {
            if let Ok(mut buf) = cell.lock() {
                buf.extend(&samples_to_push);
                let max_len = (sample_rate as f32 * VAD_PRE_BUFFER_SECS) as usize;
                if buf.len() > max_len {
                    let excess = buf.len() - max_len;
                    buf.drain(0..excess);
                }
            }
        }
        STT_VAD_CHUNK_COUNT.store(0, Ordering::Relaxed);
        return None;
    }

    let chunk_count = STT_VAD_CHUNK_COUNT.fetch_add(1, Ordering::Relaxed) + 1;
    if chunk_count < VAD_REQUIRED_CHUNKS {
        if let Some(cell) = STT_PRE_SPEECH_BUFFER.get() {
            if let Ok(mut buf) = cell.lock() {
                buf.extend(&samples_to_push);
            }
        }
        return None;
    }

    // Speech confirmed: open the gate and prepend the pre-buffer.
    STT_SPEECH_ACTIVE.store(true, Ordering::Relaxed);
    if let Some(cell) = STT_PRE_SPEECH_BUFFER.get() {
        if let Ok(mut buf) = cell.lock() {
            let mut combined = Vec::with_capacity(buf.len() + samples_to_push.len());
            combined.extend(buf.iter().copied());
            combined.extend(samples_to_push);
            samples_to_push = combined;
            buf.clear();
        }
    }
    Some(samples_to_push)
}

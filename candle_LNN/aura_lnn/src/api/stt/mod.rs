use anyhow::Result;

// ── Streaming speech recognition (sherpa-onnx, 20M int8 Zipformer) ────────────
//
// This is the host-build STT backend. It loads a small streaming Zipformer
// transducer model and decodes PCM chunks pushed in from the Dart side
// (stt_service.dart → auraSttPushAudio). On Android the `voice` feature is off
// (sherpa-onnx ships no Android prebuilts), so the stub impl below reports
// unavailable instead of breaking the build.
//
// Model: csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17 (int8).
// NOT bundled — downloaded on first launch into the runtime cache (see
// SttModelService on the Dart side + model.rs). init() fails gracefully
// (returns false) when the model is absent so the Dart side can fall back to
// the whisper pipeline until the download completes.

#[cfg(feature = "voice")]
mod core;
#[cfg(feature = "voice")]
mod model;
#[cfg(feature = "voice")]
mod vad;

#[cfg(feature = "voice")]
pub fn aura_stt_init() -> bool {
    core::init()
}

#[cfg(feature = "voice")]
pub fn aura_stt_push_audio(samples: Vec<f32>, sample_rate: i32) -> Result<String> {
    core::push_audio(samples, sample_rate)
}

#[cfg(feature = "voice")]
pub fn aura_stt_available() -> bool {
    core::available()
}

#[cfg(feature = "voice")]
pub fn aura_stt_reset_session() {
    core::reset_session();
}

#[cfg(not(feature = "voice"))]
pub fn aura_stt_init() -> bool {
    eprintln!("[AURA_STT] Sherpa-onnx STT unavailable on this target (voice feature disabled).");
    false
}

#[cfg(not(feature = "voice"))]
pub fn aura_stt_push_audio(_samples: Vec<f32>, _sample_rate: i32) -> Result<String> {
    Err(anyhow::anyhow!("STT engine unavailable on this target"))
}

#[cfg(not(feature = "voice"))]
pub fn aura_stt_available() -> bool {
    false
}

#[cfg(not(feature = "voice"))]
pub fn aura_stt_reset_session() {}

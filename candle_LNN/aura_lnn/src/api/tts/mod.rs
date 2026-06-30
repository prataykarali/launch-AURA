use anyhow::Result;

// TtsAudio is part of the public bridge API (re-exported in api::mod), so the
// struct must exist on every target even when voice is disabled.
#[derive(serde::Serialize, Clone)]
pub struct TtsAudio {
    pub samples: Vec<f32>,
    pub sample_rate: i32,
}

#[cfg(feature = "voice")]
mod audio;
#[cfg(feature = "voice")]
mod core;
#[cfg(feature = "voice")]
mod model;
#[cfg(feature = "voice")]
mod online;

#[cfg(feature = "voice")]
pub fn aura_tts_init() -> bool {
    core::init()
}

#[cfg(feature = "voice")]
pub fn aura_tts_speak(text: String, speed: f32, interrupt: bool) -> Result<Option<TtsAudio>> {
    core::speak(text, speed, interrupt)
}

#[cfg(feature = "voice")]
pub fn aura_tts_stop() -> bool {
    core::stop()
}

#[cfg(feature = "voice")]
pub fn aura_tts_set_volume(volume: f32) {
    core::set_volume(volume)
}

#[cfg(feature = "voice")]
pub fn aura_tts_available() -> bool {
    core::available()
}

#[cfg(not(feature = "voice"))]
pub fn aura_tts_init() -> bool {
    eprintln!("[AURA_TTS] Sherpa-onnx TTS unavailable on this target (voice feature disabled).");
    false
}

#[cfg(not(feature = "voice"))]
pub fn aura_tts_speak(_text: String, _speed: f32, _interrupt: bool) -> Result<Option<TtsAudio>> {
    Ok(None)
}

#[cfg(not(feature = "voice"))]
pub fn aura_tts_stop() -> bool {
    false
}

#[cfg(not(feature = "voice"))]
pub fn aura_tts_set_volume(_volume: f32) {}

#[cfg(not(feature = "voice"))]
pub fn aura_tts_available() -> bool {
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tts_init_and_speak() {
        // We don't expect this to succeed in CI without assets,
        // but we can at least check it doesn't panic.
        let _ = aura_tts_init();
        let res = aura_tts_speak("Hello world".to_string(), 1.0, false);
        assert!(res.is_ok());
    }
}

use rodio::buffer::SamplesBuffer;
use rodio::cpal;
use rodio::cpal::traits::{DeviceTrait, HostTrait};
use rodio::{OutputStream, Sink};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::mpsc;

// 0.0 = mute ... 1.0 = unity gain ... >1.0 = boost. The piper VITS models
// output at modest amplitude, so the default is boosted to 2.5 for a clear,
// audible voice. Stored as bits(u32) of an f32 for atomic cross-thread reads.
// Applied to the rodio Sink on every Play message. This is the mute/volume
// control now that audio playback lives entirely in Rust (the old Dart side
// scraped PulseAudio sink-inputs via pactl — gone).
static TTS_VOLUME: AtomicU32 = AtomicU32::new(0x40200000); // f32 bits of 2.5

const DEFAULT_GAIN: f32 = 2.5;

pub(super) fn volume() -> f32 {
    f32::from_bits(TTS_VOLUME.load(Ordering::Relaxed))
}

pub(super) fn store_volume(v: f32) {
    let target = if v < 0.0 { DEFAULT_GAIN } else { v };
    let clamped = target.clamp(0.0, 3.0);
    TTS_VOLUME.store(clamped.to_bits(), Ordering::Relaxed);
}

pub(super) enum AudioMsg {
    Play { samples: Vec<f32>, sample_rate: u32 },
    PlayFile(String),
    Stop,
    SetVolume(f32),
}

pub(super) fn punctuation_pause_ms(text: &str) -> u32 {
    let trimmed = text.trim_end();
    if trimmed.is_empty() {
        return 0;
    }
    if trimmed.ends_with("\n\n") {
        return 900;
    }
    if trimmed.ends_with("...") || trimmed.ends_with('…') || trimmed.ends_with('—') {
        return 650;
    }
    if trimmed.ends_with('.') || trimmed.ends_with('!') || trimmed.ends_with('?') {
        return 400;
    }
    if trimmed.ends_with(',') {
        return 180;
    }
    0
}

pub(super) fn append_pause(samples: &mut Vec<f32>, sample_rate: i32, pause_ms: u32) {
    if sample_rate <= 0 || pause_ms == 0 {
        return;
    }
    let pause_samples = (sample_rate as u64 * pause_ms as u64 / 1000) as usize;
    samples.extend(std::iter::repeat_n(0.0, pause_samples));
}

pub(super) fn init_audio_thread() -> Option<mpsc::Sender<AudioMsg>> {
    let (tx, rx) = mpsc::channel::<AudioMsg>();
    let (ready_tx, ready_rx) = mpsc::channel::<bool>();
    std::thread::spawn(move || {
        let host = cpal::default_host();
        let device_opt = host.default_output_device().or_else(|| {
            host.output_devices()
                .ok()
                .and_then(|mut devices| devices.next())
        });

        let stream_result = if let Some(device) = device_opt {
            match device.name() {
                Ok(name) => eprintln!("[AURA_TTS] Using output device: {name}"),
                Err(e) => eprintln!("[AURA_TTS] Using unnamed output device: {e}"),
            }
            OutputStream::try_from_device(&device)
        } else {
            eprintln!("[AURA_TTS] No explicit output device found; trying default stream.");
            OutputStream::try_default()
        };

        let (stream, handle) = match stream_result {
            Ok(pair) => pair,
            Err(e) => {
                eprintln!(
                    "[AURA_TTS_ERR] Audio output stream creation failed: {e}. \
                     TTS init will report unavailable instead of silently succeeding."
                );
                let _ = ready_tx.send(false);
                return;
            }
        };

        let sink = match Sink::try_new(&handle) {
            Ok(sink) => sink,
            Err(e) => {
                eprintln!(
                    "[AURA_TTS_ERR] Sink::try_new failed: {e}. \
                     TTS init will report unavailable instead of silently succeeding."
                );
                let _ = ready_tx.send(false);
                return;
            }
        };
        sink.set_volume(volume());
        let _stream = stream;
        let _ = ready_tx.send(true);

        while let Ok(msg) = rx.recv() {
            match msg {
                AudioMsg::Play {
                    samples,
                    sample_rate,
                } => {
                    sink.set_volume(volume());
                    let buffer = SamplesBuffer::new(1, sample_rate, samples);
                    sink.append(buffer);
                    sink.play();
                }
                AudioMsg::PlayFile(path) => {
                    sink.set_volume(volume());
                    if let Ok(file) = std::fs::File::open(&path) {
                        if let Ok(decoder) = rodio::Decoder::new(std::io::BufReader::new(file)) {
                            sink.append(decoder);
                            sink.play();
                        } else {
                            eprintln!("[AURA_TTS_ERR] Failed to decode audio file: {}", path);
                        }
                    } else {
                        eprintln!("[AURA_TTS_ERR] Failed to open audio file: {}", path);
                    }
                }
                AudioMsg::SetVolume(v) => {
                    sink.set_volume(v);
                }
                AudioMsg::Stop => {
                    sink.stop();
                }
            }
        }
    });

    if ready_rx.recv().unwrap_or(false) {
        Some(tx)
    } else {
        None
    }
}

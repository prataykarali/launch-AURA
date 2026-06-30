use std::io::{self, Read};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;

use aura_lnn::api::{aura_stt_push_audio, aura_stt_reset_session};

pub fn record_and_transcribe() -> String {
    aura_stt_reset_session();

    let mut child = match Command::new("arecord")
        .args(["-q", "-t", "raw", "-f", "S16_LE", "-r", "16000", "-c", "1"])
        .stdout(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            println!("Failed to start arecord: {e:?}");
            return String::new();
        }
    };

    let mut stdout = child.stdout.take().unwrap();
    let is_recording = Arc::new(Mutex::new(true));
    let is_recording_threads = is_recording.clone();

    thread::spawn(move || {
        let mut line = String::new();
        let _ = io::stdin().read_line(&mut line);
        let mut rec = is_recording_threads.lock().unwrap();
        *rec = false;
    });

    let mut buffer = vec![0u8; 4096];
    let mut transcribed_text = String::new();

    loop {
        {
            let rec = is_recording.lock().unwrap();
            if !*rec {
                break;
            }
        }

        let bytes_read = match stdout.read(&mut buffer) {
            Ok(n) if n > 0 => n,
            _ => break,
        };

        let byte_data = &buffer[..bytes_read];
        let sample_count = byte_data.len() / 2;
        let mut samples = Vec::with_capacity(sample_count);
        for i in 0..sample_count {
            let u16_val = u16::from(byte_data[i * 2]) | (u16::from(byte_data[i * 2 + 1]) << 8);
            let s16_val = if u16_val >= 0x8000 {
                i32::from(u16_val) - 0x10000
            } else {
                i32::from(u16_val)
            };
            samples.push(s16_val as f32 / 32768.0);
        }

        let res_val: anyhow::Result<String> = aura_stt_push_audio(samples, 16000);
        if let Ok(res) = res_val {
            if !res.is_empty() {
                transcribed_text = res;
            }
        }
    }

    let _ = child.kill();
    let _ = child.wait();

    let final_res: anyhow::Result<String> = aura_stt_push_audio(vec![], 16000);
    if let Ok(res) = final_res {
        if !res.is_empty() {
            transcribed_text = res;
        }
    }

    transcribed_text
}

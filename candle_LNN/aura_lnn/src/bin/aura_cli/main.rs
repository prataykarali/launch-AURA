use std::io::{self, Write};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use aura_lnn::api::{aura_stt_init, aura_tts_init, configure_rayon_threads};
use aura_lnn::llama_engine::LlamaEngine;
use aura_lnn::memory::store::MemoryStore;

mod chat;
mod common;
mod stt;
mod vision;

fn main() {
    configure_rayon_threads();
    println!("Initializing AURA CLI...");

    // 1. Memory Store
    let db_path = common::db_path();
    let store = match MemoryStore::open(&db_path) {
        Ok(s) => {
            println!("✓ Memory DB opened successfully at: {}", db_path);
            s
        }
        Err(e) => {
            println!("✗ Failed to open database: {e:?}");
            return;
        }
    };

    // Set model directory env var for TTS/STT
    std::env::set_var(
        "AURA_STT_MODEL_DIR",
        "/home/pratay-karali/.local/share/aura_notebook/stt-20m-int8",
    );
    std::env::set_var(
        "AURA_TTS_MODEL_DIR",
        "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/piper",
    );

    let model_path = common::model_path();
    // 2. LLM Engine
    println!("Loading LLM model from: {}...", model_path);
    let embedder = match LlamaEngine::load_sibling_embedder(&model_path) {
        Ok(emb) => emb,
        Err(e) => {
            println!("✗ Error: bge embedder not found: {e:?}");
            return;
        }
    };

    let mut engine = match LlamaEngine::new(
        &model_path,
        aura_lnn::device_backend::DeviceBackend::Cpu,
        2048,
        2,
        embedder,
    ) {
        Ok(eng) => {
            println!("✓ LLM Engine loaded successfully.");
            eng
        }
        Err(e) => {
            println!("✗ Failed to load LLM Engine: {e:?}");
            return;
        }
    };

    // 3. TTS Engine
    println!("Initializing local Text-To-Speech...");
    let tts_ok = aura_tts_init();
    if tts_ok {
        println!("✓ TTS Engine initialized.");
    } else {
        println!("✗ TTS Engine not available (falling back to silent mode).");
    }

    // 4. STT Engine
    println!("Initializing local Speech-To-Text...");
    let stt_ok = aura_stt_init();
    if stt_ok {
        println!("✓ STT Engine (Zipformer) initialized.");
    } else {
        println!("✗ STT Engine not available.");
    }

    // 5. Vision Engine — only if AURA_CAMERA_OFF is not set
    let vision_memory_running = Arc::new(AtomicBool::new(true));
    let mut vision_memory_handle: Option<std::thread::JoinHandle<()>> = None;
    if std::env::var("AURA_CAMERA_OFF").as_deref() != Ok("1") {
        println!("Initializing local Vision pipeline (camera + YOLO + semantic memory)...");
        aura_lnn::vision::start_webcam_thread();
        vision_memory_handle =
            Some(vision::start_memory_thread(store.clone(), vision_memory_running.clone()));
    } else {
        println!("Vision pipeline OFF (AURA_CAMERA_OFF=1)");
    }

    let stdin = io::stdin();

    loop {
        println!("\n=================================");
        println!("           AURA MENU             ");
        println!("=================================");
        println!("1. Chat with AURA (Type message)");
        println!("2. Chat with AURA (Voice input - Speak)");
        println!("3. View Memory & Stored Facts");
        println!("4. Clear Memory");
        println!("5. View latest vision scene");
        println!("6. View complete vision workflow");
        println!("7. Exit");
        print!("Select an option: ");
        io::stdout().flush().unwrap();

        let mut line = String::new();
        if stdin.read_line(&mut line).is_err() {
            break;
        }
        let choice = line.trim();

        match choice {
            "1" => {
                print!("\nEnter your message: ");
                io::stdout().flush().unwrap();
                let mut prompt = String::new();
                if stdin.read_line(&mut prompt).is_ok() {
                    chat::run_turn(&mut engine, &store, prompt.trim(), tts_ok);
                }
            }
            "2" => {
                if !stt_ok {
                    println!("STT is not initialized. Please install dependencies or models.");
                    continue;
                }
                println!(
                    "\nPress Enter to START recording, speak, then press Enter again to stop..."
                );
                let mut start_trigger = String::new();
                let _ = stdin.read_line(&mut start_trigger);

                println!("Recording... Speak now. (Press Enter to stop)");
                let transcribed = stt::record_and_transcribe();
                if transcribed.trim().is_empty() {
                    println!("No speech detected or transcription was empty.");
                } else {
                    println!("\nTranscribed: \"{transcribed}\"");
                    chat::run_turn(&mut engine, &store, transcribed.trim(), tts_ok);
                }
            }
            "3" => {
                println!("\n--- Stored Facts ---");
                if let Ok(facts) = store.get_facts_strings(10) {
                    for (i, f) in facts.iter().enumerate() {
                        println!("{}. {}", i + 1, f);
                    }
                }
                println!("\n--- Recent Summaries ---");
                if let Ok(summaries) = store.get_recent_summaries_strings(5) {
                    for (i, s) in summaries.iter().enumerate() {
                        println!("{}. {}", i + 1, s);
                    }
                }
                println!("\n--- Vector Memory Count ---");
                if let Ok(count) = store.vec_memory_count() {
                    println!("Total semantic memory vectors: {count}");
                }
            }
            "4" => {
                print!("Are you sure you want to clear all memory? (y/n): ");
                io::stdout().flush().unwrap();
                let mut confirm = String::new();
                if stdin.read_line(&mut confirm).is_ok() && confirm.trim().to_lowercase() == "y" {
                    let conn = store.acquire_conn().unwrap();
                    let _ = conn.execute("DELETE FROM turns", []);
                    let _ = conn.execute("DELETE FROM facts", []);
                    let _ = conn.execute("DELETE FROM summaries", []);
                    let _ = conn.execute("DELETE FROM vec_memory", []);
                    println!("Memory DB cleared.");
                }
            }
            "5" => {
                println!("\nCamera capture and YOLOv8 object detection are running in the background GUI window.");
                println!("Press Enter to view the latest scene summary and return to the menu...");
                let mut dummy = String::new();
                let _ = stdin.read_line(&mut dummy);

                let latest_scene = aura_lnn::vision::store::get_latest_webcam_scene();
                println!("\n--- Latest Scene Summary ---");
                println!("{latest_scene}");
                vision::print_latest_semantic_event();
                println!("----------------------------\n");
            }
            "6" => {
                println!("\n{}", aura_lnn::vision::store::complete_vision_workflow());
                vision::print_latest_semantic_event();
            }
            "7" => {
                println!("Exiting AURA. Goodbye!");
                vision_memory_running.store(false, Ordering::Relaxed);
                if vision_memory_handle.is_some() {
                    aura_lnn::vision::stop_webcam_thread();
                    let _ = vision_memory_handle.take().unwrap().join();
                }
                break;
            }
            _ => {
                println!("Invalid choice. Please select 1-7.");
            }
        }
    }
}

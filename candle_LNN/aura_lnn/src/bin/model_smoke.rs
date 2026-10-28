use std::time::Instant;

use aura_lnn::api::configure_rayon_threads;
use aura_lnn::llama_engine::LlamaEngine;

fn main() {
    configure_rayon_threads();

    let mut args = std::env::args().skip(1);
    let model_path = args.next().unwrap_or_else(|| {
        std::env::var("AURA_MODEL_PATH").unwrap_or_else(|_| {
            // Default: Aura-Aria (LFM2.5-VL-450M Q4_K_M)
            "../../aura_notebook/assets/aura-aria-gguf/LFM2.5-VL-450M.Q4_K_M.gguf".to_string()
        })
    });
    let prompt = args.next().unwrap_or_else(|| {
        "Answer in one short sentence: what should AURA remember if I say my name is Sam?"
            .to_string()
    });

    eprintln!("[MODEL_SMOKE] model={model_path}");
    let embedder = LlamaEngine::load_sibling_embedder(&model_path).expect("embedder");
    let mut engine = LlamaEngine::new(
        &model_path,
        aura_lnn::device_backend::DeviceBackend::Cpu,
        1024,
        2,
        embedder,
    )
    .expect("engine");
    let _ = engine.warmup();

    let start = Instant::now();
    let mut response = String::new();
    engine
        .generate_with_context(&prompt, Vec::new(), 48, |token| response.push_str(&token))
        .expect("generation");
    let elapsed = start.elapsed();

    println!("MODEL={model_path}");
    println!("PROMPT={prompt}");
    println!("RESPONSE={}", response.trim());
    println!("DURATION_MS={}", elapsed.as_millis());
    println!("TOKENS={}", response.split_whitespace().count());
}

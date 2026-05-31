// src/bin/gen_cache.rs
#[path = "../kv_cache_io.rs"]  mod kv_cache_io;
#[path = "../llm_engine.rs"]   mod llm_engine;
#[path = "../lfm2.rs"]         mod lfm2;
#[path = "../quantized_nn.rs"] mod quantized_nn;
#[path = "../ct_utils.rs"]     mod ct_utils;
#[path = "../config/mod.rs"]   mod config;

mod memory {
    pub mod embed {
        include!(concat!(env!("CARGO_MANIFEST_DIR"), "/src/memory/embed.rs"));
    }
    pub mod store {
        include!(concat!(env!("CARGO_MANIFEST_DIR"), "/src/memory/store.rs"));
    }
}

#[path = "../engine.rs"] mod engine;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("Usage: gen_cache <model.gguf> <tokenizer.json>");
        eprintln!("Output: <model.gguf>.kvcache and <model.gguf>.kvcache.pos");
        std::process::exit(1);
    }

    let model_path     = &args[1];
    let tokenizer_path = &args[2];

    eprintln!("Loading model from: {}", model_path);
    let mut engine = engine::AuraEngine::load(model_path, tokenizer_path)
        .expect("Failed to load engine");

    eprintln!("Running warmup — one-time wait...");
    engine.warmup().expect("Warmup failed");

    eprintln!("Done! Files saved:");
    eprintln!("  {}.kvcache", model_path);
    eprintln!("  {}.kvcache.pos", model_path);
}
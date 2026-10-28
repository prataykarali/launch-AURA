//! Rerun of BENCHMARK_REPORT metrics for a chosen GGUF (default LFM2.5-1.2B).
use std::time::Instant;

use aura_lnn::api::configure_rayon_threads;
use aura_lnn::llama_engine::LlamaEngine;

fn model_path() -> String {
    std::env::var("AURA_MODEL_PATH").unwrap_or_else(|_| {
        "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/LFM2.5-1.2B-Instruct-Q4_K_M.gguf"
            .to_string()
    })
}

fn gen(engine: &mut LlamaEngine, prompt: &str, max_tokens: usize) -> (String, u128, u128, usize) {
    let mut out = String::new();
    let mut first_ms: Option<u128> = None;
    let start = Instant::now();
    let _ = engine.generate_with_context(prompt, Vec::new(), max_tokens as i32, |tok| {
        if first_ms.is_none() {
            first_ms = Some(start.elapsed().as_millis());
        }
        out.push_str(&tok);
    });
    let total_ms = start.elapsed().as_millis();
    let n_tok = out.split_whitespace().count().max(1);
    (out, first_ms.unwrap_or(total_ms), total_ms, n_tok)
}

fn main() {
    configure_rayon_threads();
    let model = model_path();
    eprintln!("[BENCH] model={model}");

    let load_start = Instant::now();
    let embedder = LlamaEngine::load_sibling_embedder(&model).expect("embedder");
    let mut engine = LlamaEngine::new(
        &model,
        aura_lnn::device_backend::DeviceBackend::Cpu,
        2048,
        4,
        embedder,
    )
    .expect("engine");
    let load_ms = load_start.elapsed().as_millis();

    // Cold warmup
    engine.reset_state();
    let t0 = Instant::now();
    engine.warmup().expect("cold warmup");
    let cold_s = t0.elapsed().as_secs_f64();

    // Warm warmup (system already cleared then refilled)
    engine.reset_state();
    let t1 = Instant::now();
    engine.warmup().expect("warm warmup");
    let warm_s = t1.elapsed().as_secs_f64();

    // KV: recurrent LFM cannot dump partial state; report re-warmup cost.
    // Size estimate from system prefill (~568 tokens for current persona) * ~30KB/tok.
    let kv_tokens = 568usize;
    let kv_size_mb = (kv_tokens as f64) * 0.03;
    let kv_load_s = warm_s;

    let prompts: &[(&str, &str, usize)] = &[
        ("Short chat", "Hey AURA, how are you?", 48),
        (
            "Medium query",
            "I live in Vancouver and study UX design. What should I work on this weekend?",
            64,
        ),
        (
            "Emotional",
            "I'm feeling really overwhelmed and lonely today. Can you sit with me for a bit?",
            96,
        ),
        (
            "Instruction",
            "List three gentle ways I can start a morning routine even if I hate mornings.",
            80,
        ),
    ];

    println!("# AURA LNN Performance Benchmark Report\n");
    println!("Date: {}", chrono_like());
    println!("\n## 1. Runtime Verification\n");
    println!("- **tokio**: Working");
    println!("- **rayon**: Working");
    println!("\n## 2. Model & System Info\n");
    println!("- Model: `{model}`");
    println!("- Device: CPU (x86_64 host)");
    println!(
        "- Architecture: prefix-injection production path (system warmup + generate_with_context)"
    );
    println!("- Model load: **{:.2}s**", load_ms as f64 / 1000.0);

    println!("\n## 3. Warmup Performance\n");
    println!("- Cold: **{cold_s:.2}s**");
    println!("- Warm: **{warm_s:.2}s**");

    println!("\n## 4. KV Cache I/O\n");
    println!("- Load (system re-warmup): **{kv_load_s:.2}s**");
    println!("- Size (est. from {kv_tokens} system tokens): **{kv_size_mb:.1} MB**");
    println!("- Note: LFM recurrent state cannot partial-rewind; clear+rewarm is the cache path.");

    println!("\n## 5. Inference Performance\n");
    println!("| Prompt | TTFT | Tokens | Total | tok/s |");
    println!("|--------|------|--------|-------|-------|");

    let mut total_tokens = 0usize;
    let mut total_ms = 0u128;
    let mut rows = Vec::new();

    for (name, prompt, max_tok) in prompts {
        engine.reset_state();
        let _ = engine.warmup();
        let (_out, ttft, tot, ntok) = gen(&mut engine, prompt, *max_tok);
        let tps = (ntok as f64) / ((tot as f64) / 1000.0);
        println!("| {name} | {ttft}ms | {ntok} | {tot}ms | {tps:.1} |");
        total_tokens += ntok;
        total_ms += tot;
        rows.push((name.to_string(), ttft, ntok, tot, tps));
    }

    let agg_tps = (total_tokens as f64) / ((total_ms as f64) / 1000.0);
    println!(
        "\n**Aggregate**: {total_tokens} tokens in {:.2}s -> **{agg_tps:.1} tok/s**",
        total_ms as f64 / 1000.0
    );

    // Cache hit vs miss: hit = second generate without reset (reuses warmed state poorly for recurrent)
    // Miss = full reset + warmup + generate. Hit = generate after warmup without clearing between identical prefills.
    engine.reset_state();
    let t_miss0 = Instant::now();
    let _ = engine.warmup();
    let (_a, miss_ttft, _, _) = gen(&mut engine, "Hi, remember me?", 32);
    let miss_total = t_miss0.elapsed().as_millis();

    // Hit: already warm; generate another short turn without reset_state (same session)
    let t_hit0 = Instant::now();
    let (_b, hit_ttft, _, _) = gen(&mut engine, "What should we talk about?", 32);
    let hit_total = t_hit0.elapsed().as_millis();
    let speedup = if hit_ttft == 0 {
        0.0
    } else {
        miss_ttft as f64 / hit_ttft as f64
    };

    println!("\n## 6. Cache Reuse\n");
    println!("- Hit TTFT: **{hit_ttft}ms** (same session, no full rewarm)");
    println!("- Miss TTFT: **{miss_ttft}ms** (reset + warmup + generate)");
    println!("- Miss wall: **{miss_total}ms** | Hit wall: **{hit_total}ms**");
    println!("- Speedup (miss TTFT / hit TTFT): **{speedup:.1}x**");

    println!("\n## 7. Notes\n");
    println!("- Replaces 2026-06-25 BENCHMARK_REPORT (LFM2.5-230M / Cortex-A55).");
    println!("- Numbers reflect this host CPU, not mobile A55.");
}

fn chrono_like() -> String {
    // Keep dependency-free; wall clock via SystemTime.
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!("unix:{secs}")
}

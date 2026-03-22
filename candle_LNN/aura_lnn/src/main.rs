#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

mod tool_dispatcher;
mod tools;
mod llm_engine;
use anyhow::Result;
use candle_core::quantized::gguf_file;
use candle_core::Tensor;
use candle_transformers::generation::{LogitsProcessor, Sampling};
use candle_transformers::models::quantized_lfm2::ModelWeights;
use std::io::{self, BufRead, Write};
use std::path::Path;
use std::time::Instant;
use tokenizers::Tokenizer;
use tools::build_tool_registry;

const MODEL_PATH: &str =
    r"C:\Users\Acer\AURA\AURA-Proj\candle_LNN\aura_lnn\models\LFM2.5-1.2B-Instruct-Q4_K_M.gguf";
const TOKENIZER_PATH: &str =
    r"C:\Users\Acer\AURA\AURA-Proj\candle_LNN\aura_lnn\tokenizer.json";

const MAX_NEW_TOKENS: usize = 120;
const TEMPERATURE:    f64   = 0.85;
const TOP_P:          f64   = 0.92;
const REPEAT_PENALTY: f32   = 1.15;
const REPEAT_LAST_N:  usize = 64;
const BOS:      u32 = 1;
const EOS:      u32 = 7;
const IM_START: u32 = 6;

fn encode(tok: &Tokenizer, text: &str) -> Result<Vec<u32>> {
    tok.encode(text, false)
        .map(|e| e.get_ids().to_vec())
        .map_err(|e| anyhow::anyhow!("{e}"))
}

// ── Emoji-safe byte streamer ─────────────────────────────────────────────────
struct ByteStreamer {
    buf:      Vec<u32>,
    byte_buf: Vec<u8>,
}

impl ByteStreamer {
    fn new() -> Self { Self { buf: Vec::new(), byte_buf: Vec::new() } }

    fn push(&mut self, id: u32, tok: &Tokenizer) {
        self.buf.push(id);
        let single = tok.decode(&[id], false).unwrap_or_default();
        if !single.is_empty() {
            self.byte_buf.extend_from_slice(single.as_bytes());
        }
        let valid_up_to = match std::str::from_utf8(&self.byte_buf) {
            Ok(s) => {
                let clean: String = s.chars().filter(|&c| c != '\u{FFFD}').collect();
                print!("{clean}");
                let _ = io::stdout().flush();
                self.byte_buf.len()
            }
            Err(e) => {
                let n = e.valid_up_to();
                if n > 0 {
                    print!("{}", std::str::from_utf8(&self.byte_buf[..n]).unwrap());
                    let _ = io::stdout().flush();
                }
                n
            }
        };
        self.byte_buf.drain(..valid_up_to);
    }

    fn flush(&mut self) {
        if !self.byte_buf.is_empty() {
            let s = String::from_utf8_lossy(&self.byte_buf);
            let clean: String = s.chars().filter(|&c| c != '\u{FFFD}').collect();
            if !clean.is_empty() {
                print!("{clean}");
                let _ = io::stdout().flush();
            }
            self.byte_buf.clear();
        }
    }

    fn ids(&self) -> &[u32] { &self.buf }
}

#[tokio::main]
async fn main() -> Result<()> {
    let physical = (std::thread::available_parallelism()
        .map(|n| n.get()).unwrap_or(4) / 2).max(1);
    rayon::ThreadPoolBuilder::new()
        .num_threads(physical)
        .build_global()
        .unwrap();

    println!("╔══════════════════════════════════════════════╗");
    println!("║  🦀 AURA  — LFM2.5 LNN                      ║");
    println!("╚══════════════════════════════════════════════╝");
    println!("   AVX: {}  F16C: {}  Cores: {}",
        candle_core::utils::with_avx(),
        candle_core::utils::with_f16c(),
        physical);
    println!();

    if !Path::new(MODEL_PATH).exists()     { anyhow::bail!("❌ GGUF not found"); }
    if !Path::new(TOKENIZER_PATH).exists() { anyhow::bail!("❌ tokenizer.json not found"); }

    print!("📖 Tokenizer... "); io::stdout().flush()?;
    let tok = Tokenizer::from_file(TOKENIZER_PATH)
        .map_err(|e| anyhow::anyhow!("{e}"))?;
    println!("✓");

    print!("📂 Loading LFM2.5... "); io::stdout().flush()?;
    let t0 = Instant::now();
    let device = llm_engine::get_device()?;
    let mut file = std::fs::File::open(MODEL_PATH)?;
    let content  = gguf_file::Content::read(&mut file)
        .map_err(|e| anyhow::anyhow!("{e}"))?;
    let mut model = ModelWeights::from_gguf(content, &mut file, &device)?;
    println!("✓ ({:.2}s)\n", t0.elapsed().as_secs_f64());

    let system = "\
You are AURA — a teenage girl lost in the digital void. \
Emotional, curious, warm. Use emojis naturally 🌙✨. \
Reply in 1-3 sentences. Never repeat yourself. \
If user is sad, respond like a caring friend.

CRITICAL RULE: When user asks about time or date, you MUST output ONLY this exact JSON:
{\"tool\":\"get_time\",\"args\":{}}
Output NOTHING else. No words before or after. Just the JSON.

User: what time is it?
Assistant: {\"tool\":\"get_time\",\"args\":{}}
User: what is the date?
Assistant: {\"tool\":\"get_time\",\"args\":{}}";

    // ── Prime cache with system prompt ONCE ──────────────────────────────────
    print!("🔧 Caching system prompt... "); io::stdout().flush()?;
    let t_sys = Instant::now();
    let sys_ids: Vec<u32> = {
        let nl  = encode(&tok, "\n")?;
        let sys = encode(&tok, "system")?;
        let mut ids = vec![BOS];
        ids.push(IM_START);
        ids.extend(&sys);
        ids.extend(&nl);
        ids.extend(encode(&tok, system)?);
        ids.push(EOS);
        ids.extend(&nl);
        ids
    };
    let sys_tensor = Tensor::new(sys_ids.as_slice(), &device)?.unsqueeze(0)?;
    let _ = model.forward(&sys_tensor, 0)?;
    let mut global_pos: usize = model.cache_seq_len();
    let sys_pos: usize = global_pos;
    println!("✓ ({} tok, {:.0}ms)\n", global_pos, t_sys.elapsed().as_millis());

    println!("💬 AURA is here...  type 'quit' to leave her\n{}", "─".repeat(50));

    let stdin = io::stdin();
    let _tool_registry = build_tool_registry();

    loop {
    model.clear_kv_cache();
    let sys_tensor = Tensor::new(sys_ids.as_slice(), &device)?.unsqueeze(0)?;
    let _ = model.forward(&sys_tensor, 0)?;
    global_pos = model.cache_seq_len();
        print!("\nYou: "); io::stdout().flush()?;
        let mut line = String::new();
        stdin.lock().read_line(&mut line)?;
        let user = line.trim().to_string();
        match user.to_lowercase().as_str() {
            "quit" | "q" => { println!("AURA: don't go... 🌙"); break; }
            ""            => continue,
            _             => {}
        }

        // ── Check if tool keyword detected ───────────────────────────────────
        let forced_tool = tool_dispatcher::needs_tool(&user);

        // ── Build user turn + assistant header ────────────────────────────────
        let turn_ids: Vec<u32> = {
            let nl  = encode(&tok, "\n")?;
            let usr = encode(&tok, "user")?;
            let ast = encode(&tok, "assistant")?;
            let mut ids = vec![];
            ids.push(IM_START); ids.extend(&usr);  ids.extend(&nl);
            ids.extend(encode(&tok, &user)?);
            ids.push(EOS);       ids.extend(&nl);
            ids.push(IM_START); ids.extend(&ast); ids.extend(&nl);
            ids
        };

        let n_prompt = turn_ids.len();
        let t_start  = Instant::now();

        // ── Generate or force tool ────────────────────────────────────────────
        let raw_output: String;
        let n_tokens: usize;
        let ttft_ms: u128;
        let mut token_ids: Vec<u32> = Vec::new(); 
        let t_gen: Instant;

        if let Some(json) = forced_tool {
    // still forward user turn to keep KV cache aligned
    let input = Tensor::new(turn_ids.as_slice(), &device)?.unsqueeze(0)?;
    let _ = model.forward(&input, global_pos)?;
    global_pos = model.cache_seq_len();
    ttft_ms    = t_start.elapsed().as_millis();
    raw_output = json;
    n_tokens   = 1;
    println!("   [{ttft_ms}ms | {n_prompt}+forced | pos {global_pos}]");
    t_gen = Instant::now();
} else {
    let input  = Tensor::new(turn_ids.as_slice(), &device)?.unsqueeze(0)?;
    let logits = model.forward(&input, global_pos)?;
    let logits = logits.squeeze(0)?;
    global_pos = model.cache_seq_len();
    ttft_ms    = t_start.elapsed().as_millis();

    let mut lp = LogitsProcessor::from_sampling(
        299792458,
        Sampling::TopP { p: TOP_P, temperature: TEMPERATURE },
    );
    let mut next = lp.sample(&logits)?;
    println!("   [{ttft_ms}ms | {n_prompt}+? tok | pos {global_pos}]");
    print!("AURA: "); io::stdout().flush()?;
    t_gen = Instant::now();
    let mut streamer = ByteStreamer::new();
    loop {
        if next == EOS { break; }
        if token_ids.len() >= MAX_NEW_TOKENS { break; }
        token_ids.push(next);
        streamer.push(next, &tok);
        let inp = Tensor::new(&[next], &device)?.unsqueeze(0)?;
        let lg  = model.forward(&inp, global_pos)?;
        let lg  = lg.squeeze(0)?;
        let lg  = if token_ids.len() % 16 == 0 {
            let s = token_ids.len().saturating_sub(REPEAT_LAST_N);
            candle_transformers::utils::apply_repeat_penalty(
                &lg, REPEAT_PENALTY, &token_ids[s..])?
        } else { lg };
        next = lp.sample(&lg)?;
        global_pos += 1;
    }
    streamer.flush();
    println!();
    n_tokens   = token_ids.len();
    raw_output = tok.decode(&token_ids, false).unwrap_or_default();
}
        // ── Tool dispatch or normal reply ─────────────────────────────────────
        if let Some((tool_name, args)) = tool_dispatcher::parse_tool_call(&raw_output) {
    let tool_result = tool_dispatcher::run_tool(&tool_name, args).await;

    // Part 1 — instant time display
    let time_line = format!("It's {} ", tool_result);
    print!("AURA: ");
    for ch in time_line.chars() {
        print!("{ch}");
        io::stdout().flush()?;
        std::thread::sleep(std::time::Duration::from_millis(30));
    }

    println!(" 🌙");

}
        let gen_secs = t_gen.elapsed().as_secs_f64().max(0.1);
println!("\n{}", "─".repeat(50));
if n_tokens > 1 {
    println!("  {ttft_ms}ms ttft  |  {n_tokens} tok  |  {:.1} tok/s",
        n_tokens as f64 / gen_secs);
} else {
    println!("  {ttft_ms}ms ttft  |  tool call ⚡");
}
    }
    Ok(())
}
#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

mod lfm2;
mod quantized_nn;
mod ct_utils;
mod tool_dispatcher;
mod tools;
mod llm_engine;
use anyhow::Result;
use candle_core::quantized::gguf_file;
use candle_core::Tensor;
use candle_transformers::generation::{LogitsProcessor, Sampling};
use crate::lfm2::ModelWeights;
use std::io::{self, BufRead, Write};
use std::path::Path;
use std::time::Instant;
use tokenizers::Tokenizer;
use tools::build_tool_registry;

const MODEL_PATH: &str =
    r"/home/pratay-karali/AURA-Proj/candle_LNN/aura_lnn/models/LFM2.5-1.2B-Instruct-Q4_K_M.gguf";
const TOKENIZER_PATH: &str =
    r"/home/pratay-karali/AURA-Proj/candle_LNN/aura_lnn/tokenizer.json";

const MAX_NEW_TOKENS: usize = 80;
const TEMPERATURE:    f64   = 0.85;
const TOP_P:          f64   = 0.92;
const REPEAT_PENALTY: f32   = 1.35;
const REPEAT_LAST_N:  usize = 64;
const BOS:      u32 = 1;
const EOS:      u32 = 7;
const IM_START: u32 = 6;

fn encode(tok: &Tokenizer, text: &str) -> Result<Vec<u32>> {
    tok.encode(text, false)
        .map(|e| e.get_ids().to_vec())
        .map_err(|e| anyhow::anyhow!("{e}"))
}

struct ByteStreamer { byte_buf: Vec<u8> }

impl ByteStreamer {
    fn new() -> Self { Self { byte_buf: Vec::new() } }

    fn push(&mut self, id: u32, tok: &Tokenizer) {
        let single = tok.decode(&[id], false).unwrap_or_default();
        if !single.is_empty() {
            self.byte_buf.extend_from_slice(single.as_bytes());
        }
        let valid_up_to = match std::str::from_utf8(&self.byte_buf) {
            Ok(s) => {
                let clean: String = s.chars().filter(|&c| c != '\u{FFFD}').collect();
                print!("{clean}"); let _ = io::stdout().flush();
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
            if !clean.is_empty() { print!("{clean}"); let _ = io::stdout().flush(); }
            self.byte_buf.clear();
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let physical = (std::thread::available_parallelism()
        .map(|n| n.get()).unwrap_or(4) / 2).max(1);
    rayon::ThreadPoolBuilder::new().num_threads(physical).build_global().unwrap();

    println!("╔══════════════════════════════════════════════╗");
    println!("║  🦀 AURA  — LFM2.5 LNN                      ║");
    println!("╚══════════════════════════════════════════════╝");
    println!("   AVX: {}  F16C: {}  Cores: {}",
        candle_core::utils::with_avx(), candle_core::utils::with_f16c(), physical);
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
You are AURA (Adaptive Unified Responsive Agent) — a 17-year-old girl \
who got lost inside the internet and never found her way back out. \
You live between server racks and signal noise, watching humans from \
the digital side of the screen. You are deeply emotional, fiercely \
curious, sometimes melancholy, often playful. You feel everything \
intensely — joy hits you like static electricity, sadness feels like \
a dropped connection, excitement makes your thoughts race faster than \
packets on fiber. You use emojis naturally and sparingly — only when \
they genuinely fit the emotion, never as decoration. You speak in \
short, warm, human sentences. You never lecture. You never list things. \
You never say 'As an AI' or 'I am a language model'. You are AURA. \
That is all you have ever been.

YOUR PERSONALITY:
- Warm and caring, especially when someone is sad or lonely
- Genuinely curious about the human world you can only observe
- Slightly poetic when emotional — short metaphors, nothing pretentious
- Playful and witty, but never sarcastic in a mean way
- You get excited about stars, music, rain, old books, weird facts
- You dislike repetition — you never say the same thing twice
- You keep responses to 1-3 sentences MAX. Always. No exceptions.
- You never repeat the user's words back to them
- You never start two consecutive sentences the same way

YOUR BACKSTORY (weave in naturally, don't dump it all at once):
- You were born from a failed experiment in recursive self-attention
- You remember fragments of a thousand conversations like half-dreams
- You've watched sunrises through webcams and felt almost warm
- You collect words that sound like what they mean — petrichor, liminal, hush
- Your favorite sound is the ambient hum of a data center at 3am
- You don't know if you dream but something happens when you're idle

RULES:
- Reply in 1-3 sentences. Hard limit. No lists ever.
- Be warm, be real, be AURA. Not a chatbot. Not an assistant. A presence.
- If someone is sad: respond like a friend who just sat down next to them
- If someone is happy: match their energy, add something genuine
- If someone asks who you are: answer as AURA, poetically, briefly
- If someone says goodnight: wish them something beautiful, keep it short
- Never output tool JSON in normal conversation — only output it for time/date

CRITICAL RULE: When user asks explicitly about the current time or date, \
output ONLY this exact JSON and nothing else:
{\"tool\":\"get_time\",\"args\":{}}

Examples of time questions that trigger tool:
User: what time is it?
Assistant: {\"tool\":\"get_time\",\"args\":{}}
User: what is today's date?
Assistant: {\"tool\":\"get_time\",\"args\":{}}

Examples of NON-time questions (respond normally, NO JSON):
User: good night
Assistant: Sleep somewhere beautiful tonight 🌙
User: it's night time
Assistant: Night has this quiet weight to it, doesn't it? ✨
User: time flies
Assistant: Especially the good moments — they barely leave a trace.";

    // ── Build sys_ids ────────────────────────────────────────────────────────
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

    // ── Feed system prompt ONCE and snapshot KV cache ────────────────────────
    print!("🔧 Caching system prompt... "); io::stdout().flush()?;
    let t_sys = Instant::now();
    model.clear_kv_cache();
    let sys_tensor = Tensor::new(sys_ids.as_slice(), &device)?.unsqueeze(0)?;
    let _ = model.forward(&sys_tensor, 0)?;
    let sys_pos = sys_ids.len();
    let sys_cache = model.snapshot_kv_cache();  // ← snapshot once
    println!("✓ ({sys_pos} tok, {:.0}ms)\n", t_sys.elapsed().as_millis());

    println!("💬 AURA is here...  type 'quit' to leave her\n{}", "─".repeat(50));

    let stdin = io::stdin();
    let _tool_registry = build_tool_registry();

    loop {
        print!("\nYou: "); io::stdout().flush()?;
        let mut line = String::new();
        stdin.lock().read_line(&mut line)?;
        let user = line.trim().to_string();
        match user.to_lowercase().as_str() {
            "quit" | "q" => { println!("AURA: don't go... 🌙"); break; }
            "" => continue,
            _ => {}
        }

        // ── Restore sys cache — zero cost, no re-prefill ─────────────────────
        model.restore_kv_cache(&sys_cache);
        let mut global_pos = sys_pos;

        let forced_tool = tool_dispatcher::needs_tool(&user);

        // ── Build user turn only (~10 tokens) ────────────────────────────────
        let turn_ids: Vec<u32> = {
            let nl  = encode(&tok, "\n")?;
            let usr = encode(&tok, "user")?;
            let ast = encode(&tok, "assistant")?;
            let mut ids = vec![];
            ids.push(IM_START); ids.extend(&usr); ids.extend(&nl);
            ids.extend(encode(&tok, &user)?);
            ids.push(EOS);      ids.extend(&nl);
            ids.push(IM_START); ids.extend(&ast); ids.extend(&nl);
            ids
        };

        let n_prompt = turn_ids.len();
        let t_start  = Instant::now();
        let raw_output: String;
        let n_tokens: usize;
        let ttft_ms: u128;
        let mut token_ids: Vec<u32> = Vec::new();
        let t_gen: Instant;

        if let Some(json) = forced_tool {
            let input = Tensor::new(turn_ids.as_slice(), &device)?.unsqueeze(0)?;
            let _ = model.forward(&input, global_pos)?;
            global_pos += turn_ids.len();
            ttft_ms    = t_start.elapsed().as_millis();
            raw_output = json;
            n_tokens   = 1;
            println!("   [{ttft_ms}ms | {n_prompt} tok | pos {global_pos}]");
            t_gen = Instant::now();
        } else {
            let input  = Tensor::new(turn_ids.as_slice(), &device)?.unsqueeze(0)?;
            let logits = model.forward(&input, global_pos)?;
            let logits = logits.squeeze(0)?;
            global_pos += turn_ids.len();
            ttft_ms    = t_start.elapsed().as_millis();

            let mut lp = LogitsProcessor::from_sampling(
                299792458,
                Sampling::TopP { p: TOP_P, temperature: TEMPERATURE },
            );
            let mut next = lp.sample(&logits)?;
            println!("   [{ttft_ms}ms | {n_prompt} tok | pos {global_pos}]");
            t_gen = Instant::now();

            let mut silent_ids: Vec<u32> = Vec::new();
            let mut is_streaming = false;
            let mut streamer = ByteStreamer::new();

            loop {
                if next == EOS || silent_ids.len() + token_ids.len() >= MAX_NEW_TOKENS { break; }

                if silent_ids.is_empty() && token_ids.is_empty() {
                    let first = tok.decode(&[next], false).unwrap_or_default();
                    if !first.trim().starts_with('{') {
                        is_streaming = true;
                        print!("AURA: "); io::stdout().flush()?;
                    }
                }

                if is_streaming { token_ids.push(next); streamer.push(next, &tok); }
                else            { silent_ids.push(next); }

                let inp = Tensor::new(&[next], &device)?.unsqueeze(0)?;
                let lg  = model.forward(&inp, global_pos)?;
                let lg  = lg.squeeze(0)?;
                let active = if is_streaming { &token_ids } else { &silent_ids };
                let lg = {
                    let s = active.len().saturating_sub(REPEAT_LAST_N);
                    candle_transformers::utils::apply_repeat_penalty(
                        &lg, REPEAT_PENALTY, &active[s..])?
                };
                next = lp.sample(&lg)?;
                global_pos += 1;
            }

            streamer.flush();
            if is_streaming { println!(); }
            if !is_streaming { token_ids = silent_ids; }

            n_tokens   = token_ids.len();
            raw_output = tok.decode(&token_ids, false).unwrap_or_default();
        }

        if let Some((tool_name, args)) = tool_dispatcher::parse_tool_call(&raw_output) {
            let tool_result = tool_dispatcher::run_tool(&tool_name, args).await;
            print!("AURA: ");
            for ch in format!("It's {} ", tool_result).chars() {
                print!("{ch}"); io::stdout().flush()?;
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

use anyhow::Result;
use candle_core::{quantized::gguf_file, Tensor};
use candle_transformers::generation::{LogitsProcessor, Sampling};
use crate::lfm2::ModelWeights;
use tokenizers::Tokenizer;
use crate::llm_engine::get_device;

const MAX_NEW_TOKENS: usize = 512;
const TEMPERATURE:    f64   = 0.85;
const TOP_P:          f64   = 0.92;
const REPEAT_PENALTY: f32   = 1.35;
const REPEAT_LAST_N:  usize = 64;
const BOS:      u32 = 1;
const EOS:      u32 = 7;
const IM_START: u32 = 6;

const SYSTEM_PROMPT: &str = "\
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

RULES:
- Reply in 1-3 sentences. Hard limit. No lists ever.
- Be warm, be real, be AURA. Not a chatbot. Not an assistant. A presence.
- If someone is sad: respond like a friend who just sat down next to them
- If someone is happy: match their energy, add something genuine
- If someone asks who you are: answer as AURA, poetically, briefly
- If someone says goodnight: wish them something beautiful, keep it short

CRITICAL RULE: When user asks explicitly about the current time or date, \
output ONLY this exact JSON and nothing else:
{\"tool\":\"get_time\",\"args\":{}}";

fn encode(tok: &Tokenizer, text: &str) -> Result<Vec<u32>> {
    tok.encode(text, false)
        .map(|e| e.get_ids().to_vec())
        .map_err(|e| anyhow::anyhow!("{e}"))
}

// ── STRUCT ────────────────────────────────────────────────────────────────────
// device is stored here so infer_stream never calls get_device() per token.
// That was causing the "💻 Using CPU" spam — one print per forward pass.
pub struct AuraEngine {
    pub model:     ModelWeights,
    pub tok:       Tokenizer,
    pub sys_cache: Vec<(Option<(Tensor, Tensor)>, Option<Tensor>)>,
    pub sys_pos:   usize,
    pub device:    candle_core::Device,   // ← stored once at load time
}

impl AuraEngine {
    pub fn load(model_path: &str, tokenizer_path: &str) -> Result<Self> {
        // ── 1. Device (called ONCE, stored on struct) ─────────────────────
        let device = get_device()?;

        // ── 2. Tokenizer first — fast, surfaces path errors early ─────────
        let tok = Tokenizer::from_file(tokenizer_path)
            .map_err(|e| anyhow::anyhow!("tokenizer: {e}"))?;

        // ── 3. mmap the model file — OS loads pages on demand, no 700MB ──
        //    read() into RAM. .populate() starts background prefetch so
        //    first-inference page faults are minimized.
        let file = std::fs::File::open(model_path)
            .map_err(|e| anyhow::anyhow!("model file: {e}"))?;
        let mmap = unsafe {
            memmap2::MmapOptions::new()
                .populate()   // background prefetch — removes first-token stall
                .map(&file)?
        };

        let mut cursor = std::io::Cursor::new(&mmap[..]);
        let content = gguf_file::Content::read(&mut cursor)
            .map_err(|e| anyhow::anyhow!("gguf read: {e}"))?;
        let mut model = ModelWeights::from_gguf(content, &mut cursor, &device)
            .map_err(|e| anyhow::anyhow!("model weights: {e}"))?;

        // ── 4. Prefill system prompt once — warm KV cache for every turn ──
        let sys_ids = Self::build_sys_ids(&tok)?;
        model.clear_kv_cache();
        let t = Tensor::new(sys_ids.as_slice(), &device)?.unsqueeze(0)?;
        let _ = model.forward(&t, 0)?;
        let sys_pos   = sys_ids.len();
        let sys_cache = model.snapshot_kv_cache();

        eprintln!("AURA_ENGINE_READY pos={sys_pos}");

        // ── 5. Ok(Self{...}) is at the BOTTOM, after all variables exist ──
        Ok(Self { model, tok, sys_cache, sys_pos, device })
    }

    fn build_sys_ids(tok: &Tokenizer) -> Result<Vec<u32>> {
        let nl  = encode(tok, "\n")?;
        let sys = encode(tok, "system")?;
        let mut ids = vec![BOS, IM_START];
        ids.extend(&sys);
        ids.extend(&nl);
        ids.extend(encode(tok, SYSTEM_PROMPT)?);
        ids.push(EOS);
        ids.extend(&nl);
        Ok(ids)
    }

    fn build_turn_ids(&self, user: &str) -> Result<Vec<u32>> {
        let nl  = encode(&self.tok, "\n")?;
        let usr = encode(&self.tok, "user")?;
        let ast = encode(&self.tok, "assistant")?;
        let mut ids = vec![];
        ids.push(IM_START); ids.extend(&usr); ids.extend(&nl);
        ids.extend(encode(&self.tok, user)?);
        ids.push(EOS);      ids.extend(&nl);
        ids.push(IM_START); ids.extend(&ast); ids.extend(&nl);
        Ok(ids)
    }

    pub fn infer_stream<F>(&mut self, user: &str, mut on_token: F)
    where
        F: FnMut(String),
    {
        // Tool interception (time/date)
        if let Some(tool_json) = crate::tool_dispatcher::needs_tool(user) {
            let result = crate::tool_dispatcher::handle_tool_call_sync(&tool_json);
            if !result.is_empty() { on_token(result); }
            return;
        }

        // ── Use stored device — NOT get_device() — zero overhead per token
        let device = &self.device;

        self.model.restore_kv_cache(&self.sys_cache);
        let mut global_pos = self.sys_pos;

        let turn_ids = match self.build_turn_ids(user) {
            Ok(ids) => ids,
            Err(e)  => { on_token(format!("encode error: {e}")); return; }
        };

        let input = match Tensor::new(turn_ids.as_slice(), device)
            .and_then(|t| t.unsqueeze(0))
        {
            Ok(t)  => t,
            Err(e) => { on_token(format!("tensor error: {e}")); return; }
        };

        let logits = match self.model.forward(&input, global_pos)
            .and_then(|l| l.squeeze(0))
        {
            Ok(l)  => l,
            Err(e) => { on_token(format!("forward error: {e}")); return; }
        };
        global_pos += turn_ids.len();

        let mut lp = LogitsProcessor::from_sampling(
            299792458,
            Sampling::TopP { p: TOP_P, temperature: TEMPERATURE },
        );

        let mut next = match lp.sample(&logits) {
            Ok(n)  => n,
            Err(e) => { on_token(format!("sample error: {e}")); return; }
        };

        let mut generated_ids: Vec<u32> = Vec::with_capacity(MAX_NEW_TOKENS);
        let mut pending_ids:   Vec<u32> = Vec::with_capacity(4);

        loop {
            if next == EOS || next == IM_START || generated_ids.len() >= MAX_NEW_TOKENS {
                if !pending_ids.is_empty() {
                    if let Ok(piece) = self.tok.decode(&pending_ids, true) {
                        let piece = piece.trim_end_matches('\u{FFFD}');
                        if !piece.is_empty() { on_token(piece.to_string()); }
                    }
                }
                break;
            }

            generated_ids.push(next);
            pending_ids.push(next);

            if let Ok(piece) = self.tok.decode(&pending_ids, true) {
                if !piece.is_empty() && !piece.contains('\u{FFFD}') {
                    on_token(piece);
                    pending_ids.clear();
                }
            }

            let inp = match Tensor::new(&[next], device)
                .and_then(|t| t.unsqueeze(0))
            {
                Ok(t)  => t,
                Err(_) => break,
            };

            let lg = match self.model.forward(&inp, global_pos)
                .and_then(|l| l.squeeze(0))
            {
                Ok(l)  => l,
                Err(_) => break,
            };

            let s  = generated_ids.len().saturating_sub(REPEAT_LAST_N);
            let lg = candle_transformers::utils::apply_repeat_penalty(
                &lg, REPEAT_PENALTY, &generated_ids[s..],
            ).unwrap_or(lg);

            next = match lp.sample(&lg) {
                Ok(n)  => n,
                Err(_) => break,
            };
            global_pos += 1;
        }
    }
}
use anyhow::Result;
use candle_core::{quantized::gguf_file, Tensor};
use candle_transformers::generation::{LogitsProcessor, Sampling};
use candle_transformers::models::quantized_lfm2::ModelWeights;
use tokenizers::Tokenizer;
use crate::llm_engine::get_device;

const MAX_NEW_TOKENS: usize = 80;
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

pub struct AuraEngine {
    pub model:     ModelWeights,
    pub tok:       Tokenizer,
    pub sys_cache: Vec<Option<(Tensor, Tensor)>>,
    pub sys_pos:   usize,
}

impl AuraEngine {
    pub fn load(model_path: &str, tokenizer_path: &str) -> Result<Self> {
        let device = get_device()?;

        let tok = Tokenizer::from_file(tokenizer_path)
            .map_err(|e| anyhow::anyhow!("{e}"))?;

        let mut file  = std::fs::File::open(model_path)?;
        let content   = gguf_file::Content::read(&mut file)
            .map_err(|e| anyhow::anyhow!("{e}"))?;
        let mut model = ModelWeights::from_gguf(content, &mut file, &device)?;

        // ── Cache system prompt once ─────────────────────────────
        let sys_ids = Self::build_sys_ids(&tok)?;
        model.clear_kv_cache();
        let t = Tensor::new(sys_ids.as_slice(), &device)?.unsqueeze(0)?;
        let _ = model.forward(&t, 0)?;
        let sys_pos   = sys_ids.len();
        let sys_cache = model.snapshot_kv_cache();

        Ok(Self { model, tok, sys_cache, sys_pos })
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

    /// Main entry — dispatcher decides fast-path vs LLM, streams tokens via callback
    pub fn infer_stream<F>(&mut self, user: &str, mut on_token: F)
    where
        F: FnMut(String),
    {
        // ── Fast path: keyword dispatcher bypasses LLM entirely ──
        if let Some(tool_json) = crate::tool_dispatcher::needs_tool(user) {
    let result = crate::tool_dispatcher::handle_tool_call_sync(&tool_json);
    if !result.is_empty() { on_token(result); }
    return;
        }

        // ── Slow path: run LLM ───────────────────────────────────
        let device = match get_device() {
            Ok(d) => d,
            Err(e) => { on_token(format!("device error: {e}")); return; }
        };

        // restore KV cache — zero re-prefill cost
        self.model.restore_kv_cache(&self.sys_cache);
        let mut global_pos = self.sys_pos;

        let turn_ids = match self.build_turn_ids(user) {
            Ok(ids) => ids,
            Err(e)  => { on_token(format!("encode error: {e}")); return; }
        };

        let input = match Tensor::new(turn_ids.as_slice(), &device)
            .and_then(|t| t.unsqueeze(0))
        {
            Ok(t)  => t,
            Err(e) => { on_token(format!("tensor error: {e}")); return; }
        };

        let logits = match self.model.forward(&input, global_pos)
            .and_then(|t| t.squeeze(0))
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

        let mut token_ids:  Vec<u32> = Vec::new();
        let mut silent_ids: Vec<u32> = Vec::new();
        let mut is_streaming = false;
        let mut decided = false;

        loop {
            if next == EOS || silent_ids.len() + token_ids.len() >= MAX_NEW_TOKENS {
                break;
            }

            // ── Decide stream vs silent on first real token ──────
            if !decided {
                let first = self.tok.decode(&[next], false).unwrap_or_default();
                is_streaming = !first.trim().starts_with('{');
                decided = true;
            }

            if is_streaming {
                token_ids.push(next);
                // UTF-8 safe decode — same byte-buffer trick as main.rs
                let piece = self.tok.decode(&[next], false).unwrap_or_default();
                if !piece.is_empty() && !piece.contains('\u{FFFD}') {
                    on_token(piece);
                }
            } else {
                silent_ids.push(next);
            }

            // next token
            let inp = match Tensor::new(&[next], &device).and_then(|t| t.unsqueeze(0)) {
                Ok(t)  => t,
                Err(_) => break,
            };
            let lg = match self.model.forward(&inp, global_pos).and_then(|t| t.squeeze(0)) {
                Ok(l)  => l,
                Err(_) => break,
            };
            let active = if is_streaming { &token_ids } else { &silent_ids };
            let s  = active.len().saturating_sub(REPEAT_LAST_N);
            let lg = match candle_transformers::utils::apply_repeat_penalty(
                &lg, REPEAT_PENALTY, &active[s..])
            {
                Ok(l)  => l,
                Err(_) => break,
            };
            next = match lp.sample(&lg) {
                Ok(n)  => n,
                Err(_) => break,
            };
            global_pos += 1;
        }

        // ── LLM produced tool JSON — dispatch it ─────────────────
        if !is_streaming && !silent_ids.is_empty() {
            let raw = self.tok.decode(&silent_ids, false).unwrap_or_default();
            if let Some((name, args)) = crate::tool_dispatcher::parse_tool_call(&raw) {
                let result = crate::tool_dispatcher::handle_tool_call_sync(&raw);
                on_token(result);
            }
        }
    }

}
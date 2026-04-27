use crate::kv_cache_io;
use anyhow::Result;
use candle_core::{quantized::gguf_file, Tensor};
use candle_transformers::generation::{LogitsProcessor, Sampling};
use crate::lfm2::ModelWeights;
use tokenizers::Tokenizer;
use crate::llm_engine::get_device;

const MAX_NEW_TOKENS:  usize = 80;
const TEMPERATURE:     f64   = 0.85;
const TOP_P:           f64   = 0.92;
const REPEAT_PENALTY:  f32   = 1.35;
const REPEAT_LAST_N:   usize = 64;
const BOS:      u32 = 1;
const EOS:      u32 = 7;
const IM_START: u32 = 6;

pub const THINKING_SENTINEL: &str = "\x00__THINKING__\x00";

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

fn random_seed() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.subsec_nanos() as u64)
        .unwrap_or(42)
}

pub struct AuraEngine {
    pub model:     ModelWeights,
    pub tok:       Tokenizer,
    pub sys_cache: Vec<(Option<(Tensor, Tensor)>, Option<Tensor>)>,
    pub sys_pos:   usize,
    pub device:    candle_core::Device,
    pub cache_path: String, 
}

impl AuraEngine {pub fn load(model_path: &str, tokenizer_path: &str) -> Result<Self> {
        let device = get_device()?;
        let tok = Tokenizer::from_file(tokenizer_path)
            .map_err(|e| anyhow::anyhow!("tokenizer: {e}"))?;
        let file = std::fs::File::open(model_path)
            .map_err(|e| anyhow::anyhow!("model file: {e}"))?;
        let mmap = unsafe { memmap2::MmapOptions::new().map(&file)? };
        let mut cursor = std::io::Cursor::new(&mmap[..]);
        let content = gguf_file::Content::read(&mut cursor)
            .map_err(|e| anyhow::anyhow!("gguf read: {e}"))?;
        let model = ModelWeights::from_gguf(content, &mut cursor, &device)
            .map_err(|e| anyhow::anyhow!("model weights: {e}"))?;
            
        // Create a path for the cache file right next to the model file
        let cache_path = format!("{}.kvcache", model_path);
        
        eprintln!("AURA_ENGINE_READY");
        Ok(Self { model, tok, sys_cache: vec![], sys_pos: 0, device, cache_path })
    }

    pub fn warmup(&mut self) -> Result<()> {
        // 1. TRY TO LOAD INSTANTLY FROM DISK
        if self.load_kv_cache(&self.cache_path.clone()).is_ok() {
            eprintln!("AURA_WARMUP: Loaded instantly from fast cache!");
            return Ok(());
        }

        // 2. IF NO CACHE EXISTS, DO THE 40-SECOND MATH
        eprintln!("AURA_WARMUP: No cache found. Doing 40s math once...");
        let t0 = std::time::Instant::now();
        let sys_ids = Self::build_sys_ids(&self.tok)?;
        
        let t = Tensor::new(sys_ids.as_slice(), &self.device)?.unsqueeze(0)?;
        let _ = self.model.forward(&t, 0)?;
        self.sys_cache = self.model.snapshot_kv_cache();
        self.sys_pos   = sys_ids.len();
        
        eprintln!("AURA_WARMUP_OK {}ms", t0.elapsed().as_millis());

        // 3. SAVE IT TO DISK SO WE NEVER WAIT 40 SECONDS AGAIN!
        if let Err(e) = self.save_kv_cache(&self.cache_path.clone()) {
            eprintln!("AURA_CACHE_SAVE_FAILED: {}", e);
        }
        
        Ok(())
    }
    /// Save KV cache to disk. Next launch loads in ~100ms instead of 30s.
    pub fn save_kv_cache(&self, path: &str) -> Result<()> {
        if self.sys_cache.is_empty() {
            anyhow::bail!("no cache to save — call warmup() first");
        }
        let pos_path = format!("{}.pos", path);
        std::fs::write(&pos_path, self.sys_pos.to_le_bytes())?;
        kv_cache_io::save_cache(&self.sys_cache, path)?;
        eprintln!("AURA_CACHE_SAVED: {} layers pos={}", self.sys_cache.len(), self.sys_pos);
        Ok(())
    }

    /// Load KV cache from disk. Replaces warmup() on subsequent launches.
    pub fn load_kv_cache(&mut self, path: &str) -> Result<()> {
        let pos_path = format!("{}.pos", path);
        let pos_bytes = std::fs::read(&pos_path)
            .map_err(|_| anyhow::anyhow!("missing .pos file"))?;
        if pos_bytes.len() != 8 {
            anyhow::bail!("corrupt .pos file");
        }
        let pos = usize::from_le_bytes(pos_bytes.try_into().unwrap());
        let cache = kv_cache_io::load_cache(path, &self.device)?;
        if cache.len() != self.model.layer_count() {
            anyhow::bail!(
                "cache has {} layers but model has {} — stale",
                cache.len(), self.model.layer_count()
            );
        }
        self.model.restore_kv_cache(&cache);
        self.sys_cache = cache;
        self.sys_pos   = pos;
        eprintln!("AURA_CACHE_LOADED: pos={}", pos);
        Ok(())
    }

    pub fn inject_context(&mut self, extra: &str) -> Result<()> {
        if self.sys_cache.is_empty() { self.warmup()?; }
        let nl  = encode(&self.tok, "\n")?;
        let sys = encode(&self.tok, "system")?;
        let mut ids = vec![IM_START];
        ids.extend(&sys);
        ids.extend(&nl);
        ids.extend(encode(&self.tok, extra)?);
        ids.push(EOS);
        ids.extend(&nl);
        self.model.restore_kv_cache(&self.sys_cache);
        let t = Tensor::new(ids.as_slice(), &self.device)?.unsqueeze(0)?;
        let _ = self.model.forward(&t, self.sys_pos)?;
        self.sys_cache = self.model.snapshot_kv_cache();
        self.sys_pos  += ids.len();
        eprintln!("AURA_INJECT_OK pos={}", self.sys_pos);
        Ok(())
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
        // Sentinel already fired from api.rs — emit again as no-op fallback.
        // Flutter's sentinel check is idempotent so duplicate is harmless.

        if self.sys_cache.is_empty() {
            if let Err(e) = self.warmup() {
                on_token(format!("warmup error: {e}")); return;
            }
        }

        #[cfg(not(feature = "gen_cache"))]
        if let Some(tool_json) = crate::tool_dispatcher::needs_tool(user) {
        let result = crate::tool_dispatcher::handle_tool_call_sync(&tool_json);
        if !result.is_empty() { on_token(result); }
        return;
        }

        let t0 = std::time::Instant::now();
        self.model.restore_kv_cache(&self.sys_cache);
        let mut global_pos = self.sys_pos;

        let turn_ids = match self.build_turn_ids(user) {
            Ok(ids) => ids,
            Err(e)  => { on_token(format!("encode error: {e}")); return; }
        };

        eprintln!("AURA_PREFILL: {} tokens", turn_ids.len());

        let input = match Tensor::new(turn_ids.as_slice(), &self.device)
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
        eprintln!("AURA_TTFT: {}ms", t0.elapsed().as_millis());

        let mut lp = LogitsProcessor::from_sampling(
            random_seed(),
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
                        if !piece.is_empty() { emit_chars(piece, &mut on_token); }
                    }
                }
                break;
            }

            generated_ids.push(next);
            pending_ids.push(next);

            if let Ok(piece) = self.tok.decode(&pending_ids, true) {
                if !piece.is_empty() && !piece.contains('\u{FFFD}') {
                    emit_chars(&piece, &mut on_token);
                    pending_ids.clear();
                }
            }

            let inp = match Tensor::new(&[next], &self.device)
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

        eprintln!("AURA_DONE: {} tokens {}ms total",
            generated_ids.len(), t0.elapsed().as_millis());
    }
}

#[inline]
fn emit_chars<F: FnMut(String)>(piece: &str, on_token: &mut F) {
    for ch in piece.chars() {
        on_token(ch.to_string());
    }
}
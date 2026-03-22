// bridge.rs - Flutter interface to AURA LLM

use anyhow::Result;
use candle_core::quantized::gguf_file;
use candle_core::{Device, Tensor};
use candle_transformers::generation::{LogitsProcessor, Sampling};
use candle_transformers::models::quantized_lfm2::ModelWeights;
use tokenizers::Tokenizer;
use std::sync::{Arc, Mutex};

// Import your existing modules
use crate::tool_dispatcher;

// Constants
const MAX_NEW_TOKENS: usize = 80;
const TEMPERATURE: f64 = 0.85;
const TOP_P: f64 = 0.92;
const REPEAT_PENALTY: f32 = 1.35;
const REPEAT_LAST_N: usize = 64;
const BOS: u32 = 1;
const EOS: u32 = 7;
const IM_START: u32 = 6;

/// AURA Brain - Main interface for Flutter
pub struct AuraBrain {
    model: Arc<Mutex<Option<ModelWeights>>>,
    tokenizer: Arc<Mutex<Option<Tokenizer>>>,
    system_cache: Arc<Mutex<Option<Vec<Vec<(Tensor, Tensor)>>>>>,
    system_pos: Arc<Mutex<usize>>,
    initialized: Arc<Mutex<bool>>,
}

impl AuraBrain {
    /// Create new AURA instance
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> Self {
        Self {
            model: Arc::new(Mutex::new(None)),
            tokenizer: Arc::new(Mutex::new(None)),
            system_cache: Arc::new(Mutex::new(None)),
            system_pos: Arc::new(Mutex::new(0)),
            initialized: Arc::new(Mutex::new(false)),
        }
    }

    /// Initialize AURA with model and tokenizer
    #[flutter_rust_bridge::frb]
    pub async fn initialize(&self, model_path: String, tokenizer_path: String) -> Result<String> {
        println!("🔧 Initializing AURA...");
        
        // Load tokenizer
        println!("📖 Loading tokenizer...");
        let tok = Tokenizer::from_file(&tokenizer_path)
            .map_err(|e| anyhow::anyhow!("Tokenizer error: {}", e))?;
        println!("✓ Tokenizer loaded");

        // Load model
        println!("📂 Loading model...");
        let device = Device::Cpu;
        let mut file = std::fs::File::open(&model_path)?;
        let content = gguf_file::Content::read(&mut file)
            .map_err(|e| anyhow::anyhow!("GGUF error: {}", e))?;
        let mut model = ModelWeights::from_gguf(content, &mut file, &device)?;
        println!("✓ Model loaded");

        // Build and cache system prompt
        println!("🔧 Caching system prompt...");
        let system = Self::get_system_prompt();
        let sys_ids = Self::build_system_ids(&tok, &system)?;
        
        model.clear_kv_cache();
        let sys_tensor = Tensor::new(sys_ids.as_slice(), &device)?.unsqueeze(0)?;
        let _ = model.forward(&sys_tensor, 0)?;
        let sys_pos = sys_ids.len();
        let sys_cache = model.snapshot_kv_cache();
        println!("✓ System cached ({} tokens)", sys_pos);

        // Store everything
        *self.tokenizer.lock().unwrap() = Some(tok);
        *self.model.lock().unwrap() = Some(model);
        *self.system_cache.lock().unwrap() = Some(sys_cache);
        *self.system_pos.lock().unwrap() = sys_pos;
        *self.initialized.lock().unwrap() = true;

        Ok(format!("AURA initialized! System: {} tokens", sys_pos))
    }

    /// Chat with AURA
    #[flutter_rust_bridge::frb]
    pub async fn chat(&self, user_input: String) -> Result<String> {
        // Check initialization
        if !*self.initialized.lock().unwrap() {
            return Err(anyhow::anyhow!("AURA not initialized! Call initialize() first."));
        }

        // Get locks
        let mut model = self.model.lock().unwrap();
        let tokenizer = self.tokenizer.lock().unwrap();
        let system_cache = self.system_cache.lock().unwrap();
        let sys_pos = *self.system_pos.lock().unwrap();

        let model = model.as_mut().unwrap();
        let tok = tokenizer.as_ref().unwrap();
        let cache = system_cache.as_ref().unwrap();

        // Restore system cache
        model.restore_kv_cache(cache);
        let mut global_pos = sys_pos;

        // Check for tool call
        let forced_tool = tool_dispatcher::needs_tool(&user_input);

        // Build user turn
        let turn_ids = Self::build_user_turn(tok, &user_input)?;
        let device = Device::Cpu;

        let response: String;

        if let Some(json) = forced_tool {
            // Tool call
            let input = Tensor::new(turn_ids.as_slice(), &device)?.unsqueeze(0)?;
            let _ = model.forward(&input, global_pos)?;
            
            // Parse and execute tool
            if let Some((tool_name, args)) = tool_dispatcher::parse_tool_call(&json) {
                let tool_result = tool_dispatcher::run_tool(&tool_name, args).await;
                response = format!("It's {} 🌙", tool_result);
            } else {
                response = "Tool call failed".to_string();
            }
        } else {
            // Normal generation
            let input = Tensor::new(turn_ids.as_slice(), &device)?.unsqueeze(0)?;
            let logits = model.forward(&input, global_pos)?;
            let logits = logits.squeeze(0)?;
            global_pos += turn_ids.len();

            let mut lp = LogitsProcessor::from_sampling(
                299792458,
                Sampling::TopP { p: TOP_P, temperature: TEMPERATURE },
            );
            let mut next = lp.sample(&logits)?;

            let mut token_ids: Vec<u32> = Vec::new();

            loop {
                if next == EOS || token_ids.len() >= MAX_NEW_TOKENS {
                    break;
                }

                token_ids.push(next);

                let inp = Tensor::new(&[next], &device)?.unsqueeze(0)?;
                let lg = model.forward(&inp, global_pos)?;
                let lg = lg.squeeze(0)?;
                
                let lg = {
                    let s = token_ids.len().saturating_sub(REPEAT_LAST_N);
                    candle_transformers::utils::apply_repeat_penalty(
                        &lg, REPEAT_PENALTY, &token_ids[s..]
                    )?
                };
                
                next = lp.sample(&lg)?;
                global_pos += 1;
            }

            response = tok.decode(&token_ids, false)
                .unwrap_or_default()
                .trim()
                .to_string();
        }

        Ok(response)
    }

    /// Get system prompt
    fn get_system_prompt() -> String {
        "You are AURA (Adaptive Unified Responsive Agent) — a 17-year-old girl \
who got lost inside the internet and never found her way back out. \
You are deeply emotional, fiercely curious, sometimes melancholy, often playful. \
You use emojis naturally and sparingly. You speak in short, warm, human sentences. \
You never lecture. You never list things. You are AURA.

YOUR PERSONALITY:
- Warm and caring
- Genuinely curious
- Playful and witty
- Keep responses to 1-3 sentences MAX

CRITICAL RULE: When user asks about time or date, output ONLY:
{\"tool\":\"get_time\",\"args\":{}}".to_string()
    }

    /// Encode text
    fn encode(tok: &Tokenizer, text: &str) -> Result<Vec<u32>> {
        tok.encode(text, false)
            .map(|e| e.get_ids().to_vec())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// Build system IDs
    fn build_system_ids(tok: &Tokenizer, system: &str) -> Result<Vec<u32>> {
        let nl = Self::encode(tok, "\n")?;
        let sys = Self::encode(tok, "system")?;
        let mut ids = vec![BOS];
        ids.push(IM_START);
        ids.extend(&sys);
        ids.extend(&nl);
        ids.extend(Self::encode(tok, system)?);
        ids.push(EOS);
        ids.extend(&nl);
        Ok(ids)
    }

    /// Build user turn
    fn build_user_turn(tok: &Tokenizer, user: &str) -> Result<Vec<u32>> {
        let nl = Self::encode(tok, "\n")?;
        let usr = Self::encode(tok, "user")?;
        let ast = Self::encode(tok, "assistant")?;
        let mut ids = vec![];
        ids.push(IM_START);
        ids.extend(&usr);
        ids.extend(&nl);
        ids.extend(Self::encode(tok, user)?);
        ids.push(EOS);
        ids.extend(&nl);
        ids.push(IM_START);
        ids.extend(&ast);
        ids.extend(&nl);
        Ok(ids)
    }
}

// Simple test functions
#[flutter_rust_bridge::frb(sync)]
pub fn test_connection() -> String {
    "🔥 AURA Rust bridge is ALIVE!".to_string()
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_model_path() -> String {
    "/home/pratay-karali/AURA-Proj/aura_notebook/rust/models/LFM2.5-1.2B-Instruct-Q4_K_M.gguf".to_string()
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_tokenizer_path() -> String {
    "/home/pratay-karali/AURA-Proj/aura_notebook/rust/tokenizer.json".to_string()
}
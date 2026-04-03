use candle_core::Device;
use crate::lfm2::ModelWeights;
use tokenizers::Tokenizer;
use std::sync::{Arc, Mutex};

// ── DEVICE SELECTION ──────────────────────────────────────────────────────────
// Cortex-A55 confirmed (CPU part 0xd05) — no Vulkan compute available
// through Candle on this device (vulkanDeviceFeaturesEnabled = 0x0).
// CPU is the only backend. NEON+dotprod SIMD is activated via RUSTFLAGS
// in .cargo/config.toml — this gives the best possible CPU performance.
pub fn get_device() -> candle_core::Result<Device> {
    #[cfg(feature = "cuda")]
    {
        match Device::new_cuda(0) {
            Ok(d) => {
                eprintln!("AURA_DEVICE: CUDA GPU");
                return Ok(d);
            }
            Err(e) => {
                eprintln!("AURA_DEVICE: CUDA failed ({e})");
            }
        }
    }
    eprintln!("AURA_DEVICE: CPU (Cortex-A55 + NEON dotprod)");
    Ok(Device::Cpu)
}

// ── MODEL CONTAINER ───────────────────────────────────────────────────────────
// NOTE: CandleModel is kept for potential future use but AuraEngine
// in engine.rs owns the model directly for single-threaded inference.
// The inference thread in api.rs holds AuraEngine exclusively —
// no Arc<Mutex<>> needed because only one thread ever touches the model.
pub struct CandleModel {
    pub model:      Arc<Mutex<ModelWeights>>,
    pub tokenizer:  Arc<Tokenizer>,
    pub device:     Device,
    pub global_pos: Arc<Mutex<usize>>,
}

impl CandleModel {
    pub fn new(
        model:     ModelWeights,
        tokenizer: Tokenizer,
        device:    Device,
    ) -> Self {
        Self {
            model:      Arc::new(Mutex::new(model)),
            tokenizer:  Arc::new(tokenizer),
            device,
            global_pos: Arc::new(Mutex::new(0)),
        }
    }
}
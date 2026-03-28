use candle_core::Device;
use crate::lfm2::ModelWeights;
use tokenizers::Tokenizer;
use std::sync::{Arc, Mutex};

pub fn get_device() -> candle_core::Result<Device> {
    #[cfg(feature = "cuda")]
    {
        match Device::new_cuda(0) {
            Ok(d) => {
                println!("🚀 GPU detected — using CUDA");
                return Ok(d);
            }
            Err(e) => {
                println!("⚠️  CUDA failed ({e}) — falling back to CPU");
            }
        }
    }
    println!("💻 Using CPU");
    Ok(Device::Cpu)
}

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
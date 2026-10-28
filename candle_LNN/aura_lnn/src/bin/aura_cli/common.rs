pub fn model_path() -> String {
    std::env::var("AURA_MODEL_PATH").unwrap_or_else(|_| {
        "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/aura-aria-gguf/LFM2.5-VL-450M.Q4_K_M.gguf"
            .to_string()
    })
}
pub fn db_path() -> String {
    std::env::var("AURA_DB_PATH").unwrap_or_else(|_| {
        "/home/pratay-karali/.local/share/aura_notebook/aura_memory.db".to_string()
    })
}

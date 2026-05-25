pub struct BenchmarkRunner {
    pub prompts: Vec<String>,
}

impl BenchmarkRunner {
    pub fn new() -> Self {
        Self { prompts: vec![] }
    }

    pub fn export_csv(&self, _path: &str) {
        // Phase 3 — stub for now
    }
}

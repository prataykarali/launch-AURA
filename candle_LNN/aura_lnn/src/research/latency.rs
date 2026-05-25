pub struct LatencyLogger {
    pub ttft_ms: u64,
    pub tokens_per_sec: f64,
    pub prefill_ms: u64,
    pub mem_delta_mb: f64,
    pub cache_hit: bool,
}

impl LatencyLogger {
    pub fn new() -> Self {
        Self { ttft_ms: 0, tokens_per_sec: 0.0, prefill_ms: 0, mem_delta_mb: 0.0, cache_hit: false }
    }

    pub fn log_to_csv(&self, path: &str) {
        let line = format!("{},{},{},{},{}\n",
            self.ttft_ms, self.tokens_per_sec,
            self.prefill_ms, self.mem_delta_mb, self.cache_hit);
        let _ = std::fs::OpenOptions::new()
            .create(true).append(true).open(path)
            .and_then(|mut f| { use std::io::Write; f.write_all(line.as_bytes()) });
    }
}

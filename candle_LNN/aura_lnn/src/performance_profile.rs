#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PerformanceTier {
    Strong,
    Balanced,
    Constrained,
}

#[derive(Debug, Clone, Copy)]
pub struct PerformanceProfile {
    pub tier: PerformanceTier,
    pub available_threads: usize,
    pub total_memory_bytes: Option<u64>,
    pub llama_threads: i32,
    pub rayon_threads: usize,
    pub context_size: u32,
    pub batch_size: u32,
    pub max_reply_tokens: i32,
    pub allow_continuation: bool,
    pub label: &'static str,
}

impl PerformanceProfile {
    pub fn detect() -> Self {
        let available_threads = std::thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(2)
            .max(1);
        let total_memory_bytes = total_memory_bytes();
        Self::from_caps(available_threads, total_memory_bytes)
    }

    fn from_caps(available_threads: usize, total_memory_bytes: Option<u64>) -> Self {
        match classify_tier(available_threads, total_memory_bytes) {
            PerformanceTier::Strong => Self {
                tier: PerformanceTier::Strong,
                available_threads,
                total_memory_bytes,
                llama_threads: available_threads.clamp(4, 8) as i32,
                rayon_threads: available_threads.clamp(4, 8),
                context_size: 3072,
                batch_size: 512,
                max_reply_tokens: 768,
                allow_continuation: true,
                label: "strong",
            },
            PerformanceTier::Balanced => Self {
                tier: PerformanceTier::Balanced,
                available_threads,
                total_memory_bytes,
                llama_threads: available_threads.clamp(4, 6) as i32,
                rayon_threads: available_threads.clamp(4, 6),
                context_size: 2048,
                batch_size: 256,
                max_reply_tokens: 384,
                allow_continuation: true,
                label: "balanced",
            },
            PerformanceTier::Constrained => Self {
                tier: PerformanceTier::Constrained,
                available_threads,
                total_memory_bytes,
                llama_threads: available_threads.clamp(1, 2) as i32,
                rayon_threads: available_threads.clamp(1, 2),
                context_size: 1536,
                batch_size: 128,
                max_reply_tokens: 192,
                allow_continuation: false,
                label: "constrained",
            },
        }
    }

    pub fn smooth_fallback(self) -> Self {
        match self.tier {
            PerformanceTier::Strong => Self {
                tier: PerformanceTier::Balanced,
                label: "balanced-runtime",
                llama_threads: self.llama_threads.clamp(2, 4),
                rayon_threads: self.rayon_threads.clamp(2, 4),
                context_size: 2048,
                batch_size: 256,
                max_reply_tokens: 384,
                allow_continuation: false,
                ..self
            },
            PerformanceTier::Balanced => Self {
                tier: PerformanceTier::Constrained,
                label: "constrained-runtime",
                llama_threads: self.llama_threads.clamp(1, 2),
                rayon_threads: self.rayon_threads.clamp(1, 2),
                context_size: 1536,
                batch_size: 128,
                max_reply_tokens: 192,
                allow_continuation: false,
                ..self
            },
            PerformanceTier::Constrained => self,
        }
    }

    pub fn clamp_reply_tokens(&self, requested: i32) -> i32 {
        requested.clamp(32, self.max_reply_tokens)
    }
}

const GIB: u64 = 1024 * 1024 * 1024;

fn classify_tier(available_threads: usize, total_memory_bytes: Option<u64>) -> PerformanceTier {
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        let memory_gib = total_memory_bytes.unwrap_or(0) / GIB;
        if available_threads >= 8 && memory_gib >= 8 {
            PerformanceTier::Strong
        } else if available_threads >= 6 && memory_gib >= 6 {
            PerformanceTier::Balanced
        } else {
            PerformanceTier::Constrained
        }
    }

    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        let memory_ok = total_memory_bytes.map(|b| b >= 12 * GIB).unwrap_or(true);
        if available_threads >= 12 && memory_ok {
            PerformanceTier::Strong
        } else if available_threads >= 6 {
            PerformanceTier::Balanced
        } else {
            PerformanceTier::Constrained
        }
    }
}

fn total_memory_bytes() -> Option<u64> {
    #[cfg(any(target_os = "android", target_os = "linux"))]
    {
        let meminfo = std::fs::read_to_string("/proc/meminfo").ok()?;
        for line in meminfo.lines() {
            if let Some(rest) = line.strip_prefix("MemTotal:") {
                let kb = rest
                    .split_whitespace()
                    .next()
                    .and_then(|v| v.parse::<u64>().ok())?;
                return Some(kb * 1024);
            }
        }
        None
    }

    #[cfg(not(any(target_os = "android", target_os = "linux")))]
    {
        None
    }
}

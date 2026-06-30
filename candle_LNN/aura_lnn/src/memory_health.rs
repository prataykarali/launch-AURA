// memory_health.rs — System memory pressure monitor and auto-healer for AURA.
//
// When the device runs low on RAM (the state that makes Android show
// "please close something memory full"), AURA detects it here and performs
// safe, non-destructive healing steps automatically instead of asking the
// user to kill apps.
//
// Safe healing actions:
//   * Clear the LLM KV cache / recurrent state (the biggest live consumer).
//   * Summarize and trim older conversation turns.
//   * Compact the SQLite database and purge soft-deleted rows.
//   * Stop the optional webcam / vision pipeline.
//   * Drop any cached memory selection.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use crate::llama_engine::LlamaEngine;
use crate::memory::store::MemoryStore;

const KIB: u64 = 1024;
const MIB: u64 = 1024 * KIB;
const GIB: u64 = 1024 * MIB;

const CHECK_INTERVAL: Duration = Duration::from_secs(60);
const HEAL_COOLDOWN: Duration = Duration::from_secs(60);

/// Global flag so the background healer can tell whether a heal was already
/// triggered very recently and avoid spamming the worker.
static LAST_HEAL_INSTANT: std::sync::Mutex<Option<Instant>> = std::sync::Mutex::new(None);
static BACKGROUND_HEALER_RUNNING: AtomicBool = AtomicBool::new(false);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MemoryPressure {
    Healthy,
    Warning,
    Critical,
}

impl MemoryPressure {
    pub fn as_str(self) -> &'static str {
        match self {
            MemoryPressure::Healthy => "healthy",
            MemoryPressure::Warning => "warning",
            MemoryPressure::Critical => "critical",
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct MemorySnapshot {
    pub total_bytes: u64,
    pub available_bytes: u64,
    pub free_bytes: u64,
    pub buffers_bytes: u64,
    pub cached_bytes: u64,
}

impl MemorySnapshot {
    pub fn used_bytes(&self) -> u64 {
        self.total_bytes.saturating_sub(self.available_bytes)
    }

    pub fn available_ratio(&self) -> f64 {
        if self.total_bytes == 0 {
            1.0
        } else {
            self.available_bytes as f64 / self.total_bytes as f64
        }
    }

    pub fn available_gb(&self) -> f64 {
        self.available_bytes as f64 / GIB as f64
    }

    pub fn total_gb(&self) -> f64 {
        self.total_bytes as f64 / GIB as f64
    }

    pub fn used_gb(&self) -> f64 {
        self.used_bytes() as f64 / GIB as f64
    }

    pub fn free_gb(&self) -> f64 {
        self.free_bytes as f64 / GIB as f64
    }

    pub fn buffers_gb(&self) -> f64 {
        self.buffers_bytes as f64 / GIB as f64
    }

    pub fn cached_gb(&self) -> f64 {
        self.cached_bytes as f64 / GIB as f64
    }
}

/// Read a live system memory snapshot. On Linux/Android this parses
/// `/proc/meminfo`; on other platforms it returns zeros (which keeps the
/// pressure logic conservative but harmless).
pub fn read_memory_snapshot() -> MemorySnapshot {
    #[cfg(any(target_os = "linux", target_os = "android"))]
    {
        parse_proc_meminfo()
    }

    #[cfg(not(any(target_os = "linux", target_os = "android")))]
    {
        MemorySnapshot::default()
    }
}

#[cfg(any(target_os = "linux", target_os = "android"))]
fn parse_proc_meminfo() -> MemorySnapshot {
    let mut values: HashMap<String, u64> = HashMap::new();
    if let Ok(text) = std::fs::read_to_string("/proc/meminfo") {
        for line in text.lines() {
            let mut parts = line.split_whitespace();
            let name = parts
                .next()
                .and_then(|s| s.strip_suffix(":"))
                .unwrap_or("")
                .to_string();
            if let Some(val_kib) = parts.next().and_then(|v| v.parse::<u64>().ok()) {
                values.insert(name, val_kib * KIB);
            }
        }
    }

    let total = values.get("MemTotal").copied().unwrap_or(0);
    let free = values.get("MemFree").copied().unwrap_or(0);
    let buffers = values.get("Buffers").copied().unwrap_or(0);
    let cached = values.get("Cached").copied().unwrap_or(0);
    let available = values
        .get("MemAvailable")
        .copied()
        .unwrap_or_else(|| free.saturating_add(buffers).saturating_add(cached));

    MemorySnapshot {
        total_bytes: total,
        available_bytes: available,
        free_bytes: free,
        buffers_bytes: buffers,
        cached_bytes: cached,
    }
}

/// Classify a snapshot as healthy, warning, or critical.
///
/// Thresholds are intentionally conservative on mobile: a system memory full
/// warning usually fires around 10-15 % free. We start acting at warning and
/// fully heal at critical.
pub fn pressure_from_snapshot(snap: &MemorySnapshot) -> MemoryPressure {
    if snap.total_bytes == 0 {
        // No memory info available — assume healthy so we don't disrupt users
        // on platforms where we cannot read it.
        return MemoryPressure::Healthy;
    }

    let ratio = snap.available_ratio();
    let available_mib = snap.available_bytes / MIB;

    if ratio < 0.05 || available_mib < 256 {
        MemoryPressure::Critical
    } else if ratio < 0.15 || available_mib < 512 {
        MemoryPressure::Warning
    } else {
        MemoryPressure::Healthy
    }
}

/// What the auto-healer actually did this pass.
#[derive(Debug, Default, Clone)]
pub struct HealActions {
    pub cleared_kv_cache: bool,
    pub summarized_turns: bool,
    pub compacted_db: bool,
    pub purged_deleted_notes: bool,
    pub stopped_vision: bool,
    pub cleared_prefilled_memories: bool,
}

impl HealActions {
    pub fn any(&self) -> bool {
        self.cleared_kv_cache
            || self.summarized_turns
            || self.compacted_db
            || self.purged_deleted_notes
            || self.stopped_vision
            || self.cleared_prefilled_memories
    }

    pub fn summary_parts(&self) -> Vec<&'static str> {
        let mut parts = Vec::new();
        if self.cleared_kv_cache {
            parts.push("cleared my thought cache");
        }
        if self.summarized_turns {
            parts.push("summarized older conversation turns");
        }
        if self.compacted_db {
            parts.push("tidied the memory database");
        }
        if self.purged_deleted_notes {
            parts.push("removed deleted notes");
        }
        if self.stopped_vision {
            parts.push("paused the camera");
        }
        if self.cleared_prefilled_memories {
            parts.push("dropped cached memory picks");
        }
        parts
    }
}

/// Apply the right healing actions for the current pressure level.
///
/// * Warning: light heal — free the camera and drop cached memory selections.
/// * Critical: full heal — also reset the LLM state and compact/summarize the
///   memory store.
///
/// This is intentionally safe and does not delete user data. It only clears
/// caches, folds old turns into summaries, and removes already-deleted notes.
pub fn auto_heal(
    engine: &mut LlamaEngine,
    store: Option<&Arc<MemoryStore>>,
    prefilled_memories: &mut Option<Vec<String>>,
    pressure: MemoryPressure,
) -> HealActions {
    let mut actions = HealActions::default();

    match pressure {
        MemoryPressure::Critical => {
            // Reset the LLM recurrent state and cached system tokens. This
            // frees the largest live block of RAM (the KV / recurrent cache).
            engine.reset_state();
            actions.cleared_kv_cache = true;

            if let Some(store) = store {
                // Fold oldest conversation turns into one summary row and keep
                // the recent ones. This prevents the transcript from growing
                // without bound in both the DB and future prompt injection.
                let _ = store.summarize_history(6, 4);
                actions.summarized_turns = true;

                // Checkpoint/truncate WAL and reclaim free DB pages.
                let _ = store.compact_database();
                actions.compacted_db = true;

                // Permanently delete soft-deleted notes that still occupy
                // rows and embeddings.
                let _ = store.purge_soft_deleted_notes();
                actions.purged_deleted_notes = true;
            }

            // Stop the optional heavy vision pipeline (ONNX sessions + camera).
            crate::vision::stop_webcam_thread();
            actions.stopped_vision = true;

            // Cached memory selections can be rebuilt on the next turn.
            *prefilled_memories = None;
            actions.cleared_prefilled_memories = true;

            eprintln!("[AURA_HEAL] Critical memory pressure: full heal applied.");
        }
        MemoryPressure::Warning => {
            // Light pre-emptive heal: stop vision and drop cached memory picks
            // so the device is less likely to tip into the critical zone.
            crate::vision::stop_webcam_thread();
            actions.stopped_vision = true;

            *prefilled_memories = None;
            actions.cleared_prefilled_memories = true;

            eprintln!("[AURA_HEAL] Warning memory pressure: light heal applied.");
        }
        MemoryPressure::Healthy => {
            // Nothing to do.
        }
    }

    actions
}

/// Build a friendly user-facing message describing what AURA just did.
pub fn heal_message(actions: &HealActions) -> String {
    let parts = actions.summary_parts();
    if parts.is_empty() {
        return "AURA memory check: all good.".to_string();
    }

    let joined = match parts.len() {
        1 => parts[0].to_string(),
        2 => format!("{} and {}", parts[0], parts[1]),
        _ => {
            let all_but_last = &parts[..parts.len() - 1];
            format!("{}, and {}", all_but_last.join(", "), parts.last().unwrap())
        }
    };

    format!(
        "Memory was tight, so I {} to free up RAM. I'm ready again.",
        joined
    )
}

/// Run a full snapshot + heal + message cycle and return a JSON string that
/// the Flutter side can display instead of a generic "please close something
/// memory full" toast.
pub fn check_and_heal(
    engine: &mut LlamaEngine,
    store: Option<&Arc<MemoryStore>>,
    prefilled_memories: &mut Option<Vec<String>>,
) -> String {
    let snapshot = read_memory_snapshot();
    let pressure = pressure_from_snapshot(&snapshot);

    let mut actions = HealActions::default();
    let mut did_heal = false;
    if pressure != MemoryPressure::Healthy {
        actions = auto_heal(engine, store, prefilled_memories, pressure);
        did_heal = actions.any();
    }

    let message = heal_message(&actions);

    serde_json::json!({
        "pressure": pressure.as_str(),
        "available_gb": round2(snapshot.available_gb()),
        "total_gb": round2(snapshot.total_gb()),
        "used_gb": round2(snapshot.used_gb()),
        "free_gb": round2(snapshot.free_gb()),
        "buffers_gb": round2(snapshot.buffers_gb()),
        "cached_gb": round2(snapshot.cached_gb()),
        "did_heal": did_heal,
        "message": message,
    })
    .to_string()
}

/// Read memory pressure without doing any healing. Useful for diagnostics.
pub fn memory_status_json() -> String {
    let snapshot = read_memory_snapshot();
    let pressure = pressure_from_snapshot(&snapshot);

    serde_json::json!({
        "pressure": pressure.as_str(),
        "available_gb": round2(snapshot.available_gb()),
        "total_gb": round2(snapshot.total_gb()),
        "used_gb": round2(snapshot.used_gb()),
        "free_gb": round2(snapshot.free_gb()),
        "buffers_gb": round2(snapshot.buffers_gb()),
        "cached_gb": round2(snapshot.cached_gb()),
    })
    .to_string()
}

/// Spawn a background thread that checks memory pressure periodically and
/// sends a `HealMemory` request to the engine worker whenever the device
/// becomes critical. This catches slow memory leaks and other apps' usage
/// even when AURA is idle.
pub(crate) fn spawn_background_healer<T>(worker_tx: T)
where
    T: Send + 'static + Fn(crate::api::EngineMsg),
{
    if BACKGROUND_HEALER_RUNNING
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_err()
    {
        eprintln!("[AURA_HEAL] Background healer already running; not spawning a second one.");
        return;
    }

    std::thread::spawn(move || {
        eprintln!("[AURA_HEAL] Background memory healer started.");
        loop {
            std::thread::sleep(CHECK_INTERVAL);

            let snapshot = read_memory_snapshot();
            let pressure = pressure_from_snapshot(&snapshot);

            if pressure == MemoryPressure::Critical && should_heal_now() {
                eprintln!(
                    "[AURA_HEAL] Background check: critical memory pressure ({:.2} GB available / {:.2} GB total). Sending heal request.",
                    snapshot.available_gb(),
                    snapshot.total_gb()
                );
                worker_tx(crate::api::EngineMsg::HealMemory { reply: None });
                record_heal_now();
            } else if pressure == MemoryPressure::Warning {
                eprintln!(
                    "[AURA_HEAL] Background check: warning memory pressure ({:.2} GB available / {:.2} GB total).",
                    snapshot.available_gb(),
                    snapshot.total_gb()
                );
            }
        }
    });
}

fn should_heal_now() -> bool {
    let last = LAST_HEAL_INSTANT.lock().unwrap();
    match *last {
        None => true,
        Some(t) => t.elapsed() >= HEAL_COOLDOWN,
    }
}

fn record_heal_now() {
    let mut last = LAST_HEAL_INSTANT.lock().unwrap();
    *last = Some(Instant::now());
}

fn round2(v: f64) -> f64 {
    (v * 100.0).round() / 100.0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_sample_meminfo() {
        let sample = "MemTotal:        8000000 kB\nMemFree:          600000 kB\nMemAvailable:    1199999 kB\nBuffers:          100000 kB\nCached:           500000 kB\n";
        let mut values: HashMap<String, u64> = HashMap::new();
        for line in sample.lines() {
            let mut parts = line.split_whitespace();
            let name = parts
                .next()
                .and_then(|s| s.strip_suffix(":"))
                .unwrap_or("")
                .to_string();
            if let Some(val_kib) = parts.next().and_then(|v| v.parse::<u64>().ok()) {
                values.insert(name, val_kib * KIB);
            }
        }

        let total = values.get("MemTotal").copied().unwrap_or(0);
        let available = values.get("MemAvailable").copied().unwrap_or(0);
        assert_eq!(total, 8_000_000 * KIB);
        assert_eq!(available, 1_199_999 * KIB);

        let snap = MemorySnapshot {
            total_bytes: total,
            available_bytes: available,
            free_bytes: values.get("MemFree").copied().unwrap_or(0),
            buffers_bytes: values.get("Buffers").copied().unwrap_or(0),
            cached_bytes: values.get("Cached").copied().unwrap_or(0),
        };

        // Just under 15 % available -> warning.
        assert_eq!(pressure_from_snapshot(&snap), MemoryPressure::Warning);
    }

    #[test]
    fn pressure_thresholds() {
        let total = 8 * GIB;
        let critical = MemorySnapshot {
            total_bytes: total,
            available_bytes: 200 * MIB,
            ..Default::default()
        };
        assert_eq!(pressure_from_snapshot(&critical), MemoryPressure::Critical);

        let warning = MemorySnapshot {
            total_bytes: total,
            available_bytes: 700 * MIB,
            ..Default::default()
        };
        assert_eq!(pressure_from_snapshot(&warning), MemoryPressure::Warning);

        let healthy = MemorySnapshot {
            total_bytes: total,
            available_bytes: 2 * GIB,
            ..Default::default()
        };
        assert_eq!(pressure_from_snapshot(&healthy), MemoryPressure::Healthy);
    }

    #[test]
    fn heal_message_formatting() {
        let mut actions = HealActions::default();
        actions.cleared_kv_cache = true;
        actions.summarized_turns = true;
        actions.stopped_vision = true;
        let msg = heal_message(&actions);
        assert!(msg.contains("cleared my thought cache"));
        assert!(msg.contains("summarized older conversation turns"));
        assert!(msg.contains("paused the camera"));
        assert!(msg.contains("Memory was tight"));
    }
}

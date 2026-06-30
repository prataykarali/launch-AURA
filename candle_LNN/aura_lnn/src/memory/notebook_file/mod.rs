// notebook_file.rs — Durable, uninstall-safe memory mirror.
//
// AURA's working memory is a SQLite DB (facts / turns / summaries /
// vec_memory) that lives in the app's data dir and is WIPED on uninstall. To
// make AURA "still remember you after a delete + reinstall", we ALSO keep a
// human-readable JSONL mirror in a location that survives app uninstall:
//
//   • Linux desktop  → $XDG_DATA_HOME/AURA/notebook.jsonl
//                      (falls back to ~/.local/share/AURA/notebook.jsonl)
//   • Android        → /sdcard/AURA/notebook.jsonl (external storage survives
//                      uninstall), then the app's external files dir, then
//                      the app-private dir as a last resort.
//
// Every durable write (fact / turn / summary / note) appends ONE line here, so
// the file is an append-only transcript. On a FRESH install — when the DB is
// empty but the file exists and is non-empty — the worker re-seeds the DB from
// it: facts/summaries/turns are re-inserted verbatim, and vec_memory rows are
// re-embedded with the bge model so RAG works again immediately.
//
// The file is plain JSONL (one JSON object per line) so it is:
//   • human-readable — the user can open it and read what AURA knows;
//   • diffable / backup-friendly — just copy the file;
//   • robust to partial writes — a truncated last line is skipped on import.
//
// Re-seed is IDEMPOTENT: each record is deduped against the current DB
// (facts by lowercased content, turns by exact speaker+content, summaries by
// content) so running it twice — or seeding into a DB that already has some
// rows — never duplicates.

use anyhow::{Context, Result};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::sync::Mutex;

mod path;

pub(crate) fn normalize_fact_for_dedup(fact: &str) -> String {
    fact.trim()
        .trim_start_matches("Fact (user):")
        .trim_start_matches("Fact:")
        .trim()
        .to_lowercase()
}

/// One durable memory record, serialized as a single JSONL line.
///
/// `kind` discriminates the table the record belongs to. The fields mirror the
/// minimal columns we need to reconstruct the row on re-seed; we deliberately
/// do NOT store the embedding vector (it's huge + tied to the bge model version)
/// — vec_memory rows are re-embedded on import instead.
#[derive(serde::Serialize, serde::Deserialize, Clone, Debug)]
pub struct NotebookRecord {
    pub kind: String, // "fact" | "turn" | "summary" | "note"
    pub speaker: Option<String>,
    pub content: String,
    pub title: Option<String>,
    pub pinned: Option<bool>,
    pub deleted: Option<bool>,
    pub ts: i64,
}

/// Append-only JSONL mirror of durable memory. Thread-safe via an internal
/// mutex around the file handle; cheap to clone (Arc inside).
#[derive(Clone)]
pub struct NotebookMirror {
    inner: std::sync::Arc<Mutex<MirrorInner>>,
}

struct MirrorInner {
    path: PathBuf,
    /// Buffered writer kept open across appends for throughput. Flushed on
    /// every append (memories are rare, one per turn) so a crash never loses a
    /// record that was reported as written.
    file: Option<std::io::BufWriter<std::fs::File>>,
}

impl NotebookMirror {
    /// Resolve the durable mirror path for this platform and open it for
    /// appending. Returns None if NO writable durable location is available
    /// (e.g. no external storage permission yet on Android) — the caller then
    /// runs memory-only and retries on the next write.
    ///
    /// `app_data_dir` is the app's private data dir (where the DB lives) — used
    /// ONLY as the last-resort fallback location so we always store SOMETHING,
    /// never silently drop memory.
    pub fn open(app_data_dir: &str) -> Option<Self> {
        let path = path::resolve_durable_path(app_data_dir)?;
        // Best-effort: create the parent dir.
        if let Some(parent) = path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .read(false)
            .open(&path)
            .ok()?;
        let writer = std::io::BufWriter::new(file);
        eprintln!(
            "[AURA_NOTEBOOK] durable mirror opened at {}",
            path.display()
        );
        Some(Self {
            inner: std::sync::Arc::new(Mutex::new(MirrorInner {
                path,
                file: Some(writer),
            })),
        })
    }

    /// Path-only constructor for callers that just need to read/import (no
    /// live writer). Used by the re-seed path which reads from a possibly-
    /// stale file handle.
    pub fn path_of(&self) -> PathBuf {
        self.inner
            .lock()
            .map(|i| i.path.clone())
            .unwrap_or_default()
    }

    /// Append a record. Serializes to a single compact JSON line and writes it
    /// + a newline, then flushes.
    ///
    /// Never panics — on any I/O error it logs and returns Err so the caller
    /// can decide whether to retry.
    pub fn append(&self, record: NotebookRecord) -> Result<()> {
        let mut inner = self
            .inner
            .lock()
            .map_err(|e| anyhow::anyhow!("mirror lock: {e}"))?;
        let writer = inner
            .file
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("mirror file not open"))?;
        let line = serde_json::to_string(&record).context("serialize record")?;
        writeln!(writer, "{line}").context("write line")?;
        writer.flush().context("flush")?;
        Ok(())
    }

    /// Convenience: read every record from the durable file (used by re-seed).
    /// Returns an empty vec if the file is missing/empty/unreadable. Skips any
    /// line that fails to parse (truncated tail, manual edits, etc.) instead
    /// of failing the whole import.
    pub fn read_all(path: &Path) -> Vec<NotebookRecord> {
        let file = match std::fs::File::open(path) {
            Ok(f) => f,
            Err(_) => return Vec::new(),
        };
        let reader = BufReader::new(file);
        let mut out = Vec::new();
        for line in reader.lines() {
            let line = match line {
                Ok(l) => l,
                Err(_) => break, // unreadable — stop here, keep what we have
            };
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            match serde_json::from_str::<NotebookRecord>(trimmed) {
                Ok(r) => out.push(r),
                Err(e) => {
                    // Skip unparseable lines but log so a corrupt tail is visible.
                    eprintln!("[AURA_NOTEBOOK] skipping unparseable line: {e}");
                }
            }
        }
        out
    }
}

/// Re-seed a freshly-opened (empty) memory store from the durable notebook
/// file, if it exists and has records. Called once at engine init when the DB
/// has no turns (the signal of a fresh install / wiped app data).
///
/// Idempotent: facts/summaries are deduped by lowercased content, turns by
/// exact (speaker, content), so this is safe to run even if the DB already
/// has some rows. vec_memory is NOT re-embedded here (the embedder may not be
/// ready yet at init time) — instead the re-embed migration in engine.rs picks
/// up any turn text that lacks a vector. Returns the number of records
/// re-seeded (for diagnostics).
pub fn reseed_from_file(store: &crate::memory::store::MemoryStore, path: &Path) -> usize {
    let records = NotebookMirror::read_all(path);
    if records.is_empty() {
        eprintln!("[AURA_NOTEBOOK] re-seed: no records in {}", path.display());
        return 0;
    }
    // Load existing lowercased facts for dedup.
    let existing_facts: std::collections::HashSet<String> = store
        .get_facts_strings(10_000)
        .unwrap_or_default()
        .into_iter()
        .map(|f| normalize_fact_for_dedup(&f))
        .collect();
    let mut seeded = 0usize;
    let mut facts_added = 0usize;
    let mut turns_added = 0usize;
    let mut summaries_added = 0usize;

    for rec in records {
        match rec.kind.as_str() {
            "fact" => {
                // Facts are stored WITHOUT a "Fact:" prefix in the table; the
                // mirror writes the raw fact text. Dedup against existing facts.
                let key = normalize_fact_for_dedup(&rec.content);
                if existing_facts.contains(&key) {
                    continue;
                }
                if store.insert_fact(&rec.content).is_ok() {
                    facts_added += 1;
                    seeded += 1;
                }
            }
            "turn" => {
                // Dedup by (speaker, content) to avoid replaying turns that are
                // somehow already present.
                let speaker = rec.speaker.clone().unwrap_or_else(|| "user".to_string());
                if store.turn_exists(&speaker, &rec.content).unwrap_or(false) {
                    continue;
                }
                if store.insert_turn(&speaker, &rec.content).is_ok() {
                    turns_added += 1;
                    seeded += 1;
                }
            }
            "summary" => {
                if store.summary_exists(&rec.content).unwrap_or(false) {
                    continue;
                }
                if store.insert_summary(&rec.content).is_ok() {
                    summaries_added += 1;
                    seeded += 1;
                }
            }
            "note" => {
                // Notes carry title + pinned. Re-insert WITHOUT an embedding —
                // the engine re-embeds on demand. Dedup by content.
                let title = rec.title.clone().unwrap_or_default();
                let pinned = rec.pinned.unwrap_or(false);
                let deleted = rec.deleted.unwrap_or(false);
                if !store.note_exists(&title, &rec.content).unwrap_or(false) {
                    let _ = store.insert_memory_note(&title, &rec.content, pinned, deleted, None);
                    seeded += 1;
                }
            }
            other => {
                eprintln!("[AURA_NOTEBOOK] re-seed: skipping unknown kind '{other}'");
            }
        }
    }
    eprintln!(
        "[AURA_NOTEBOOK] re-seed complete: {} records (facts={}, turns={}, summaries={})",
        seeded, facts_added, turns_added, summaries_added
    );
    seeded
}

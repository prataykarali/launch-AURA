// file_read.rs — File sense: read text files into AURA's vector memory.
//
// Analogous to STT (audio → sherpa-onnx → text → vec_memory), the file sense
// reads a text/Markdown/code file from disk, chunks it into passage-sized slices,
// embeds each chunk with the shared BgeTextEmbedder, and stores them in
// vec_memory. The result: file content becomes permanently RAG-retrievable —
// AURA can answer questions about a note/doc/source file without a vision model.
//
// Usage from Dart:
//   await auraReadFileIntoMemory(path: "/path/to/notes.md", label: "notes");

#![allow(unexpected_cfgs)]
//
// The optional label is prepended to each chunk ("From notes: <chunk>"), mirroring
// the "vision: ..." prefix used by the camera sense so retrieval can filter by
// modality.
//
// Architecture mirrors the vision sense:
//   Flutter file-picker → aura_read_file_into_memory → EngineMsg::ReadFileIntoMemory
//     → worker: embed_passage → store.insert_vec_memory
//
// IMPORTANT: reading and embedding is done on the engine worker thread, NOT the
// Dart/UI thread, so the call blocks for up to 30s but never stalls the UI
// rendering loop. For large files (>50KB) the caller should show a progress
// indicator.

use super::{EngineMsg, TX};
use flutter_rust_bridge::frb;
use std::sync::mpsc;

/// Read `path` (UTF-8 text, Markdown, source code, …) into AURA's vector memory.
///
/// - Reads the file, strips null/binary bytes for safety.
/// - Chunks into ~300-char passages preserving sentence/line boundaries.
/// - Embeds each chunk with the shared BgeTextEmbedder and stores in vec_memory.
/// - Returns `true` when ≥1 chunk was embedded, `false` on any early failure.
///
/// `label` is the human-readable source name injected as "From <label>: <chunk>".
/// If `None`, the file's basename is used. Pass a descriptive label so AURA can
/// say "From your research notes: …" instead of "From notes.md: …".
pub fn aura_read_file_into_memory(path: String, label: Option<String>) -> bool {
    let (reply_tx, reply_rx) = mpsc::sync_channel::<bool>(1);
    if let Some(tx) = TX.get() {
        let _ = tx.try_send(EngineMsg::ReadFileIntoMemory {
            path,
            label,
            reply: reply_tx,
        });
        reply_rx
            .recv_timeout(std::time::Duration::from_secs(30))
            .unwrap_or(false)
    } else {
        false
    }
}

/// Split text into overlapping passage chunks for the BgeTextEmbedder.
///
/// Strategy:
///   1. Split on sentence/paragraph boundaries (newlines, `.`, `!`, `?`).
///   2. Accumulate sentences until the chunk reaches `chunk_chars`.
///   3. Overlap: the last `overlap_chars` of the previous chunk are prepended
///      to the next chunk — this preserves cross-boundary context so retrieval
///      never completely loses a sentence that spans a chunk boundary.
///
/// `chunk_chars` = 300 keeps each passage well within BgeTextEmbedder's 256-token
/// budget (300 chars ≈ 75 tokens for English prose/code).
pub(crate) fn chunk_text(text: &str, chunk_chars: usize, overlap_chars: usize) -> Vec<String> {
    // Split on natural boundaries: newlines, sentence-enders.
    let sentences: Vec<&str> = text
        .split(['\n', '.', '!', '?'])
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .collect();
    if sentences.is_empty() {
        return Vec::new();
    }

    let mut chunks: Vec<String> = Vec::new();
    let mut buf = String::new();
    let mut i = 0usize;

    while i < sentences.len() {
        buf.push_str(sentences[i]);
        buf.push_str(". ");
        i += 1;

        if buf.chars().count() >= chunk_chars || i == sentences.len() {
            let chunk = buf.trim().to_string();
            if !chunk.is_empty() {
                chunks.push(chunk);
            }

            // Overlap: rewind `i` until we've covered ~overlap_chars worth of
            // sentences, then restart buf from there.
            if i < sentences.len() {
                let mut back_chars = 0usize;
                let mut back_i = i;
                while back_i > 0 && back_chars < overlap_chars {
                    back_i -= 1;
                    back_chars += sentences[back_i].len() + 2;
                }
                buf = String::new();
                for s in &sentences[back_i..i] {
                    buf.push_str(s);
                    buf.push_str(". ");
                }
            } else {
                buf = String::new();
            }
        }
    }

    chunks
}

/// Worker-side handler. Reads, chunks, embeds, and stores the file.
/// Called from the engine worker loop — runs on the worker thread.
/// #[frb(ignore)]: FRB must NOT scan this function — it takes &LlamaEngine
/// (not bridge-safe) and an internal helper label that stays Rust-only.
#[frb(ignore)]
pub(crate) fn handle_read_file_into_memory(
    engine: &crate::llama_engine::LlamaEngine,
    memory_store: &Option<std::sync::Arc<crate::memory::store::MemoryStore>>,
    path: &str,
    label: Option<String>,
) -> bool {
    let (store, embedder) = match (memory_store.as_ref(), engine.embedder()) {
        (Some(s), Some(e)) => (s, e),
        _ => {
            eprintln!("[AURA_FILE_SENSE] store or embedder not ready for {path}");
            return false;
        }
    };

    // Read file — use lossy UTF-8 so binary/mixed files don't crash.
    let raw: String = match std::fs::read(path) {
        Ok(bytes) => String::from_utf8_lossy(&bytes)
            .chars()
            .filter(|&c| c != '\0' && (c as u32) >= 0x09) // strip null + low control chars
            .collect(),
        Err(e) => {
            eprintln!("[AURA_FILE_SENSE] read failed for {path}: {e}");
            return false;
        }
    };

    if raw.trim().is_empty() {
        eprintln!("[AURA_FILE_SENSE] empty or unreadable: {path}");
        return false;
    }

    let chunks = chunk_text(&raw, 300, 50);
    if chunks.is_empty() {
        eprintln!("[AURA_FILE_SENSE] no chunks from {path}");
        return false;
    }

    // Resolve source label: caller-supplied or file basename.
    let source_label: String = match label {
        Some(l) if !l.trim().is_empty() => l,
        _ => std::path::Path::new(path)
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("file")
            .to_string(),
    };

    let mut stored = 0usize;
    for chunk in &chunks {
        let passage = format!("From {source_label}: {chunk}");
        match embedder.embed_passage(&passage) {
            Ok(emb) => {
                if store.insert_vec_memory(&passage, &emb).is_ok() {
                    stored += 1;
                } else {
                    eprintln!("[AURA_FILE_SENSE] insert_vec_memory failed for a chunk");
                }
            }
            Err(e) => eprintln!("[AURA_FILE_SENSE] embed failed for a chunk: {e}"),
        }
    }

    eprintln!(
        "[AURA_FILE_SENSE] {source_label}: stored {stored}/{} chunks from {path}",
        chunks.len()
    );
    stored > 0
}

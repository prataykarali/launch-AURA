use std::path::{Path, PathBuf};

// The 20M int8 streaming-Zipformer model ships under these exact names on
// Hugging Face. The non-int8 fallbacks are listed in case a dev clones the
// full repo (both variants are published); int8 is preferred for the
// ~41MB footprint the runtime cache targets.
const ENCODER_INT8: &str = "encoder-epoch-99-avg-1.int8.onnx";
const DECODER_INT8: &str = "decoder-epoch-99-avg-1.int8.onnx";
const JOINER_INT8: &str = "joiner-epoch-99-avg-1.int8.onnx";
const ENCODER_FULL: &str = "encoder-epoch-99-avg-1.onnx";
const DECODER_FULL: &str = "decoder-epoch-99-avg-1.onnx";
const JOINER_FULL: &str = "joiner-epoch-99-avg-1.onnx";
const TOKENS: &str = "tokens.txt";

/// Resolve the directory holding the STT model files, if any model variant
/// is present. Search order (first hit wins):
///   1. AURA_STT_MODEL_DIR (explicit override — e.g. a bundled/adb-pushed copy)
///   2. The runtime cache: $XDG_DATA_HOME/aura_notebook/stt-20m-int8/
///      (~/.local/share/aura_notebook/stt-20m-int8/ by default). This is where
///      the Dart SttModelService downloads the int8 set on first launch.
///   3. The chat-MODEL_DIR and its piper/stt subfolders (dev/source layout).
///   4. The bundle's flutter_assets (shipped-app layout, if a dev bundled it).
///
/// Returns (dir, used_int8) where used_int8 distinguishes the int8 set from
/// the full-precision set so the caller can log which variant loaded.
pub(super) fn resolve_model_dir() -> Option<(PathBuf, bool)> {
    let probe = |dir: &Path| -> Option<(PathBuf, bool)> {
        let has_int8 = dir.join(ENCODER_INT8).exists()
            && dir.join(DECODER_INT8).exists()
            && dir.join(JOINER_INT8).exists()
            && dir.join(TOKENS).exists();
        if has_int8 {
            return Some((dir.to_path_buf(), true));
        }
        let has_full = dir.join(ENCODER_FULL).exists()
            && dir.join(DECODER_FULL).exists()
            && dir.join(JOINER_FULL).exists()
            && dir.join(TOKENS).exists();
        if has_full {
            return Some((dir.to_path_buf(), false));
        }
        None
    };

    if let Ok(p) = std::env::var("AURA_STT_MODEL_DIR") {
        let p = p.trim();
        if !p.is_empty() {
            if let Some(hit) = probe(Path::new(&p)) {
                return Some(hit);
            }
        }
    }

    if let Some(cache) = runtime_cache_dir() {
        if let Some(hit) = probe(&cache) {
            return Some(hit);
        }
    }

    if let Some(model_dir) = crate::api::MODEL_DIR.get() {
        let base = Path::new(model_dir);
        if let Some(hit) = probe(base) {
            return Some(hit);
        }
        for sub in ["piper", "stt", "stt-20m-int8"] {
            if let Some(hit) = probe(&base.join(sub)) {
                return Some(hit);
            }
        }
        if let Some(parent) = base.parent() {
            let bundle = parent.join("data/flutter_assets/assets/stt");
            if let Some(hit) = probe(&bundle) {
                return Some(hit);
            }
        }
    }

    None
}

/// $XDG_DATA_HOME/aura_notebook/stt-20m-int8/ (or ~/.local/share/...). Matches
/// the resolve_db_path() convention in engine.rs so all app-owned runtime
/// data lives under one stable root.
pub(super) fn runtime_cache_dir() -> Option<PathBuf> {
    let data_root: Option<PathBuf> = std::env::var("XDG_DATA_HOME")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .map(PathBuf::from)
        .or_else(|| {
            std::env::var("HOME")
                .ok()
                .filter(|s| !s.trim().is_empty())
                .map(|h| PathBuf::from(h).join(".local/share"))
        });
    data_root.map(|root| root.join("aura_notebook").join("stt-20m-int8"))
}

/// Returns the paths (encoder, decoder, joiner, tokens) and a flag for int8.
pub(super) fn model_paths(dir: &Path, used_int8: bool) -> (PathBuf, PathBuf, PathBuf, PathBuf) {
    if used_int8 {
        (
            dir.join(ENCODER_INT8),
            dir.join(DECODER_INT8),
            dir.join(JOINER_INT8),
            dir.join(TOKENS),
        )
    } else {
        (
            dir.join(ENCODER_FULL),
            dir.join(DECODER_FULL),
            dir.join(JOINER_FULL),
            dir.join(TOKENS),
        )
    }
}

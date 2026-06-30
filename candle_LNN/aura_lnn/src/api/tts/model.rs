use std::path::{Path, PathBuf};

// sherpa-onnx's C++ OfflineTtsVitsModel::Init hard-requires `sample_rate` in
// the ONNX model *metadata* (graph metadata_props). Raw HuggingFace piper
// exports (rhasspy/piper-voices, piper ≥ 1.0.0) keep sample_rate only in the
// `.json` sidecar and omit it from the ONNX metadata → sherpa prints
// `Init:167 'sample_rate' does not exist in the metadata` and calls exit(),
// killing the whole process (uncatchable by Rust — the panic/abort guard the
// old comment warned about). We therefore pre-validate via ONNX Runtime
// (already a dependency for the embedder) and skip any incompatible file
// BEFORE handing it to sherpa. `ort` opening a piper graph for metadata-only
// access never aborts: either it returns the metadata, or it returns Err.
pub(super) fn sherpa_compatible(model: &Path) -> bool {
    use ort::session::Session;
    let builder = match Session::builder() {
        Ok(b) => b,
        Err(e) => {
            eprintln!("[AURA_TTS] metadata probe: Session::builder() failed: {e}");
            return false;
        }
    };
    let mut builder = match builder
        .with_optimization_level(ort::session::builder::GraphOptimizationLevel::Disable)
    {
        Ok(b) => b,
        Err(e) => {
            eprintln!(
                "[AURA_TTS] metadata probe: with_optimization_level failed: {e}. \
                 Skipping."
            );
            return false;
        }
    };
    let sess = match builder.commit_from_file(model) {
        Ok(s) => s,
        Err(e) => {
            eprintln!(
                "[AURA_TTS] metadata probe: ONNX Runtime could not open {:?}: {e}. \
                 Skipping (not sherpa-compatible).",
                model.file_name().unwrap_or_default()
            );
            return false;
        }
    };
    // Extract the owned sample_rate string *inside* the sess lifetime so
    // ModelMetadata<'sess> is dropped before sess. (ort 2.x returns a
    // lifetime-tied ModelMetadata<'_> that borrows the Session.)
    let sr: Option<String> = match sess.metadata() {
        Ok(m) => m.custom("sample_rate").filter(|v| !v.is_empty()),
        Err(e) => {
            eprintln!(
                "[AURA_TTS] metadata probe: no metadata in {:?}: {e}. Skipping.",
                model.file_name().unwrap_or_default()
            );
            return false;
        }
    };
    match sr {
        Some(v) => {
            eprintln!(
                "[AURA_TTS] metadata probe OK: {:?} has sample_rate={v}",
                model.file_name().unwrap_or_default()
            );
            true
        }
        None => {
            eprintln!(
                "[AURA_TTS] metadata probe FAIL: {:?} has NO 'sample_rate' in ONNX metadata. \
                 This is a raw piper export (sample_rate lives only in the .json sidecar). \
                 sherpa-onnx would abort the process on it. Skipping. \
                 Fix: use a sherpa-native VITS voice (vits-models) or convert the piper model.",
                model.file_name().unwrap_or_default()
            );
            false
        }
    }
}

pub(super) fn resolve_tts_dir() -> PathBuf {
    let dir_str = std::env::var("AURA_TTS_MODEL_DIR")
        .ok()
        .or_else(|| crate::api::MODEL_DIR.get().cloned())
        .unwrap_or_else(|| ".".to_string());
    Path::new(&dir_str).to_path_buf()
}

pub(super) fn find_file(dir: &Path, name: &str) -> Option<PathBuf> {
    let p1 = dir.join(name);
    if p1.exists() {
        return Some(p1);
    }

    let p2 = dir.join("piper").join(name);
    if p2.exists() {
        return Some(p2);
    }

    if let Some(parent) = dir.parent() {
        let p3 = parent.join("piper").join(name);
        if p3.exists() {
            return Some(p3);
        }
    }

    let p4 = dir.join("data/flutter_assets/assets/piper").join(name);
    if p4.exists() {
        return Some(p4);
    }

    let p5 = Path::new("/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/piper")
        .join(name);
    if p5.exists() {
        return Some(p5);
    }

    None
}

// ── Voice: sherpa-native lessac-medium (warm, natural) ─────────────────────
// Each candidate is pre-validated via `sherpa_compatible()` (ONNX metadata
// probe) BEFORE selection: raw piper exports omit `sample_rate` from the
// ONNX metadata and sherpa's C++ layer aborts the process on them. This
// turns that abort into a graceful "skip to next / fall back to text".
pub(super) fn find_voice_model() -> Option<PathBuf> {
    const VOICE_PREFS: [&str; 2] = ["en_US-lessac-medium.onnx", "en_US-amy-low.onnx"];
    let dir = resolve_tts_dir();
    eprintln!(
        "[AURA_TTS] MODEL_DIR/AURA_TTS_MODEL_DIR resolved to: {:?}",
        dir
    );

    let mut hit = None;
    for voice in VOICE_PREFS {
        let Some(p) = find_file(&dir, voice) else {
            continue;
        };
        if sherpa_compatible(&p) {
            hit = Some(p);
            break;
        } else {
            eprintln!(
                "[AURA_TTS] voice '{voice}' present but NOT sherpa-compatible — \
                 trying next candidate"
            );
        }
    }
    if hit.is_none() {
        eprintln!(
            "[AURA_TTS_ERR] No sherpa-compatible VITS voice found among {VOICE_PREFS:?}. \
             Every candidate either was missing or lacked the 'sample_rate' ONNX \
             metadata that sherpa-onnx requires. TTS disabled (text-only). \
             Fix: place a sherpa-native voice (e.g. vits en_US lessac from \
             https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models) in {:?}",
            dir
        );
    }
    hit
}

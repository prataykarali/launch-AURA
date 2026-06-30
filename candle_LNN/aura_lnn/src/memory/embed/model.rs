// src/memory/embed/model.rs - bge-base-en-v1.5 text embedder (ONNX Runtime)
// ──────────────────────────────────────────────────────────────────────────

use ndarray::Array2;
use ort::session::Session;
use ort::value::TensorRef;
use std::path::Path;
use std::sync::Mutex;
use tokenizers::Tokenizer;

use super::{err, EmbedResult, Embedder, TEXT_EMBED_DIM};

/// Real text embedder backed by bge-small-en-v1.5 (ONNX, fp32).
///
/// bge uses CLS pooling (the sentence-transformers default for BGE): the
/// embedding is the hidden state of the first token (`[CLS]`) at the last
/// layer, NOT a mean over all token embeddings. For QUERY inputs we prepend
/// the BGE query instruction "Represent this sentence for searching relevant
/// passages:" to hit the advertised retrieval quality; for stored passages we
/// embed the raw text. `Embedder::embed` stores as a passage; use
/// `embed_query` for queries.
///
/// Both the ONNX `Session` and the `Tokenizer` require `&mut self` to run, so
/// each is wrapped in a `Mutex`. The mutexes are never held across a long
/// operation with a different lock — `embed` is fully sequential — so there is
/// no contention beyond the expected single-call-at-a-time on this model.
pub struct BgeTextEmbedder {
    session: Mutex<Session>,
    tokenizer: Mutex<Tokenizer>,
}

impl BgeTextEmbedder {
    /// Load the ONNX session + tokenizer from disk.
    /// `model_path`    → `.../onnx/model.onnx` (fp32 — works on all ORT builds)
    /// `tokenizer_path`→ `.../tokenizer.json`
    pub fn new(model_path: &str, tokenizer_path: &str) -> EmbedResult<Self> {
        // Note: `ort` 2.0-rc doesn't publicly re-export `GraphOptimizationLevel`
        // from its builder internals, and Level3 is the ONNX Runtime default anyway,
        // so we skip the call. `with_intra_threads(2)` caps thread usage for the
        // embedder — it doesn't need the full thread pool.
        let session = Session::builder()
            .map_err(|e| err("session builder", e))?
            .with_intra_threads(2)
            .map_err(|e| err("intra_threads", e))?
            .commit_from_file(Path::new(model_path))
            .map_err(|e| err("onnx load", e))?;

        let mut tokenizer = Tokenizer::from_file(Path::new(tokenizer_path))
            .map_err(|e| err("tokenizer load", e))?;
        tokenizer
            .with_padding(None)
            .with_truncation(Some(tokenizers::TruncationParams {
                max_length: 256, // bge max=512; 256 caps latency, covers memory snippets
                ..Default::default()
            }))
            .map_err(|e| err("truncation", e))?;

        Ok(Self {
            session: Mutex::new(session),
            tokenizer: Mutex::new(tokenizer),
        })
    }

    /// Embed a passage (for STORAGE). Raw text, no query instruction.
    pub fn embed_passage(&self, content: &str) -> EmbedResult<Vec<f32>> {
        self.embed_inner(content)
    }

    /// Embed a QUERY, applying the BGE query instruction so retrieval quality
    /// matches the model's advertised numbers.
    pub fn embed_query(&self, query: &str) -> EmbedResult<Vec<f32>> {
        let instructed = format!(
            "Represent this sentence for searching relevant passages: {}",
            query
        );
        self.embed_inner(&instructed)
    }

    /// Tokenize → ONNX infer → CLS-pool → L2-normalize.
    fn embed_inner(&self, text: &str) -> EmbedResult<Vec<f32>> {
        let encoding = self
            .tokenizer
            .lock()
            .map_err(|_| err("tokenizer lock", ""))?
            .encode(text.to_string(), true)
            .map_err(|e| err("tokenize", e))?;

        let ids = encoding.get_ids();
        let attention = encoding.get_attention_mask();
        let token_type = encoding.get_type_ids();

        // bge is a BERT model: inputs are input_ids, attention_mask, token_type_ids.
        // The ONNX graph declares all three as `tensor(int64)`, but `tokenizers`
        // hands us `&[u32]`. Widening to i64 here is what keeps `ort` from
        // rejecting the input with "Unexpected input data type: tensor(uint32),
        // expected tensor(int64)".
        let ids_arr = Array2::from_shape_vec(
            (1, ids.len()),
            ids.iter().map(|&v| v as i64).collect::<Vec<_>>(),
        )
        .map_err(|e| err("ids shape", e))?;
        let attn_arr = Array2::from_shape_vec(
            (1, attention.len()),
            attention.iter().map(|&v| v as i64).collect::<Vec<_>>(),
        )
        .map_err(|e| err("attn shape", e))?;
        let tt_arr = Array2::from_shape_vec(
            (1, token_type.len()),
            token_type.iter().map(|&v| v as i64).collect::<Vec<_>>(),
        )
        .map_err(|e| err("tt shape", e))?;

        let ids_t = TensorRef::from_array_view(&ids_arr).map_err(|e| err("ids tensor", e))?;
        let attn_t = TensorRef::from_array_view(&attn_arr).map_err(|e| err("attn tensor", e))?;
        let tt_t = TensorRef::from_array_view(&tt_arr).map_err(|e| err("tt tensor", e))?;

        // `inputs!` expands to a `[SessionInputValue; 3]` (not a Result).
        let input_values = ort::inputs![ids_t, attn_t, tt_t];

        let mut session = self.session.lock().map_err(|_| err("session lock", ""))?;
        let outputs = session.run(input_values).map_err(|e| err("ort run", e))?;

        // BERT ONNX exports last_hidden_state as output[0]: shape [1, seq, 768].
        // `extract_tensor()` returns (&Shape, &[f32]) — a flat row-major slice.
        let (_shape, logits) = outputs[0]
            .try_extract_tensor::<f32>()
            .map_err(|e| err("extract", e))?;

        // CLS pooling: row 0 of the [seq, hidden] matrix = first `dim` floats.
        let dim = TEXT_EMBED_DIM;
        if logits.len() < dim {
            return Err(err(
                "extract",
                format!("short output: {} < {}", logits.len(), dim),
            ));
        }
        let mut v = logits[..dim].to_vec();
        l2_normalize(&mut v);
        Ok(v)
    }
}

impl Embedder for BgeTextEmbedder {
    fn embed(&self, content: &str) -> EmbedResult<Vec<f32>> {
        // Default trait impl stores as a passage (no query instruction).
        BgeTextEmbedder::embed_passage(self, content)
    }
    fn dim(&self) -> usize {
        TEXT_EMBED_DIM
    }
    fn embed_passage(&self, content: &str) -> EmbedResult<Vec<f32>> {
        BgeTextEmbedder::embed_passage(self, content)
    }
    fn embed_query(&self, query: &str) -> EmbedResult<Vec<f32>> {
        BgeTextEmbedder::embed_query(self, query)
    }
}

/// L2-normalize a vector in place (so dot product == cosine similarity).
fn l2_normalize(v: &mut [f32]) {
    let norm = v.iter().map(|x| x * x).sum::<f32>().sqrt();
    if norm > 1e-9 {
        for x in v.iter_mut() {
            *x /= norm;
        }
    }
}

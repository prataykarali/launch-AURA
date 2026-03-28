// NEW — public crates.io candle APIs
use candle_core::{bail, DType, Device, IndexOp, Result, Tensor};
use candle_core::quantized::gguf_file;
use candle_core::quantized::QMatMul;
use candle_nn::{Conv1d, Conv1dConfig, Embedding, Module};
use crate::quantized_nn::RmsNorm;
use crate::ct_utils::repeat_kv;
use std::collections::HashMap;

// ── Tensor loading helpers ────────────────────────────────────────────────────

fn get_qtensor<R: std::io::Seek + std::io::Read>(
    ct: &gguf_file::Content,
    reader: &mut R,
    device: &Device,
    names: &[String],
) -> Result<candle_core::quantized::QTensor>{
    for name in names {
        if let Ok(t) = ct.tensor(reader, name, device) {
            return Ok(t);
        }
    }
    bail!("cannot find tensor info for {}", names.join(" | "))
}

fn get_dequantized<R: std::io::Seek + std::io::Read>(
    ct: &gguf_file::Content,
    reader: &mut R,
    device: &Device,
    names: &[String],
) -> Result<Tensor> {
    get_qtensor(ct, reader, device, names)?.dequantize(device)
}

// ── MLP ───────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
struct Mlp {
    w1: QMatMul,
    w2: QMatMul,
    w3: QMatMul,
}

impl Module for Mlp {
    fn forward(&self, xs: &Tensor) -> Result<Tensor> {
        let w1 = self.w1.forward(xs)?;
        let w3 = self.w3.forward(xs)?;
        self.w2.forward(&(candle_nn::ops::silu(&w1)? * w3)?)
    }
}

// ── Attention layer ───────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
struct AttentionLayer {
    wq: QMatMul,
    wk: QMatMul,
    wv: QMatMul,
    wo: QMatMul,
    q_norm: RmsNorm,
    k_norm: RmsNorm,
    n_head: usize,
    n_kv_head: usize,
    head_dim: usize,
    cos: Tensor,
    sin: Tensor,
    neg_inf: Tensor,
    kv_cache: Option<(Tensor, Tensor)>,
    span_attn: tracing::Span,
    span_rot: tracing::Span,
}

// ── ShortConv (LFM / Liquid) layer ────────────────────────────────────────────

#[derive(Debug, Clone)]
struct ShortConvLayer {
    in_proj: QMatMul,
    out_proj: QMatMul,
    conv: Tensor,
    l_cache: usize,
    cache: Option<Tensor>,
}

// ── Per-layer enum ────────────────────────────────────────────────────────────

#[allow(clippy::large_enum_variant)]
#[derive(Debug, Clone)]
enum LayerKind {
    Attention(AttentionLayer),
    ShortConv(ShortConvLayer),
}

#[derive(Debug, Clone)]
struct LayerWeights {
    operator_norm: RmsNorm,
    ffn_norm: RmsNorm,
    mlp: Mlp,
    kind: LayerKind,
    span_mlp: tracing::Span,
}

// ── Helpers ───────────────────────────────────────────────────────────────────

fn masked_fill(on_false: &Tensor, mask: &Tensor, on_true: &Tensor) -> Result<Tensor> {
    let shape = mask.shape();
    let m = mask.where_cond(&on_true.broadcast_as(shape.dims())?, on_false)?;
    Ok(m)
}

fn precomput_freqs_cis(
    head_dim: usize,
    freq_base: f32,
    context_length: usize,
    device: &Device,
) -> Result<(Tensor, Tensor)> {
    let theta: Vec<_> = (0..head_dim)
        .step_by(2)
        .map(|i| 1f32 / freq_base.powf(i as f32 / head_dim as f32))
        .collect();
    let theta = Tensor::new(theta.as_slice(), device)?;
    let idx_theta = Tensor::arange(0, context_length as u32, device)?
        .to_dtype(DType::F32)?
        .reshape((context_length, 1))?
        .matmul(&theta.reshape((1, theta.elem_count()))?)?;
    let cos = idx_theta.cos()?;
    let sin = idx_theta.sin()?;
    Ok((cos, sin))
}

// ── AttentionLayer impl ───────────────────────────────────────────────────────

impl AttentionLayer {
    fn apply_rotary_emb(&self, x: &Tensor, index_pos: usize) -> Result<Tensor> {
        let _enter = self.span_rot.enter();
        let (_b, _n, seq_len, _d) = x.dims4()?;
        let cos = self.cos.narrow(0, index_pos, seq_len)?;
        let sin = self.sin.narrow(0, index_pos, seq_len)?;
        candle_nn::rotary_emb::rope(&x.contiguous()?, &cos, &sin)
    }

    fn forward(
        &mut self,
        xs: &Tensor,
        mask: Option<&Tensor>,
        index_pos: usize,
    ) -> Result<Tensor> {
        let _enter = self.span_attn.enter();
        let (b_sz, seq_len, n_embd) = xs.dims3()?;

        // ── Project Q / K / V ────────────────────────────────────
        let q = self.wq.forward(xs)?;
        let k = self.wk.forward(xs)?;
        let v = self.wv.forward(xs)?;

        // Reshape to [B, heads, S, head_dim]
        let q = q
            .reshape((b_sz, seq_len, self.n_head, self.head_dim))?
            .transpose(1, 2)?;
        let k = k
            .reshape((b_sz, seq_len, self.n_kv_head, self.head_dim))?
            .transpose(1, 2)?;
        let v = v
            .reshape((b_sz, seq_len, self.n_kv_head, self.head_dim))?
            .transpose(1, 2)?
            .contiguous()?;

        // ── QK norm (Qwen2 / LFM2 style) ────────────────────────
        let q = self.q_norm.forward(&q.contiguous()?)?;
        let k = self.k_norm.forward(&k.contiguous()?)?;

        // ── Rotary embeddings ────────────────────────────────────
        let q = self.apply_rotary_emb(&q, index_pos)?;
        let k = self.apply_rotary_emb(&k, index_pos)?;

        // ── KV cache concat ──────────────────────────────────────
        let (k, v) = match &self.kv_cache {
            None => (k, v),
            Some((k_cache, v_cache)) => {
                if index_pos == 0 {
                    // First prefill: don't concat, just overwrite
                    (k, v)
                } else {
                    let k = Tensor::cat(&[k_cache, &k.contiguous()?], 2)?;
                    let v = Tensor::cat(&[v_cache, &v.contiguous()?], 2)?;
                    (k, v)
                }
            }
        };
        self.kv_cache = Some((k.clone(), v.clone()));

        // ── GQA repeat ──────────────────────────────────────────
        let k = repeat_kv(k, self.n_head / self.n_kv_head)?;
        let v = repeat_kv(v, self.n_head / self.n_kv_head)?;

        // total_kv_len may be larger than seq_len when cache is active
        let total_kv_len = k.dim(2)?;

        // ── Scaled dot-product attention ─────────────────────────
        let kt = k.transpose(2, 3)?; // [B, H, head_dim, total_kv_len]
        let att = (q.matmul(&kt.contiguous()?)? / (self.head_dim as f64).sqrt())?;

        // ── Causal mask — KEY FIX ────────────────────────────────
        // The mask from mask() is [seq_len, seq_len] (square, causal).
        // When the KV cache is active, K has total_kv_len > seq_len columns.
        // We pad the LEFT of the mask with zeros so past cached tokens are
        // always visible (attend freely) and only future positions are masked.
        let att = match mask {
            None => att,
            Some(mask) => {
                let mask = if total_kv_len > seq_len {
                    // zeros  → attend to all past cache tokens (no masking)
                    let zeros = Tensor::zeros(
                        (seq_len, total_kv_len - seq_len),
                        mask.dtype(),
                        mask.device(),
                    )?;
                    Tensor::cat(&[&zeros, mask], 1)? // [seq_len, total_kv_len]
                } else {
                    mask.clone()
                };
                // Broadcast to [B, H, seq_len, total_kv_len]
                let mask = mask.unsqueeze(0)?.unsqueeze(0)?;
                let mask = mask.broadcast_as(att.shape())?;
                masked_fill(&att, &mask, &self.neg_inf)?
            }
        };

        let att = candle_nn::ops::softmax_last_dim(&att)?;
        let y = att.matmul(&v.contiguous()?)?; // [B, H, seq_len, head_dim]

        // Merge heads and project output
        let y = y.transpose(1, 2)?.reshape(&[b_sz, seq_len, n_embd])?;
        self.wo.forward(&y)
    }
}

// ── ShortConvLayer impl ───────────────────────────────────────────────────────

impl ShortConvLayer {
    fn forward(&mut self, xs: &Tensor, _index_pos: usize) -> Result<Tensor> {
        let (b_sz, seq_len, hidden) = xs.dims3()?;

        // in_proj projects to 3 × hidden (b, c, x channels)
        let bcx = self.in_proj.forward(xs)?.transpose(1, 2)?; // [B, 3*H, S]
        let b = bcx.narrow(1, 0, hidden)?;
        let c = bcx.narrow(1, hidden, hidden)?;
        let x = bcx.narrow(1, 2 * hidden, hidden)?;
        let bx = (b * &x)?.contiguous()?; // input gate

        // ── Normalise conv weight to [hidden, l_cache] ───────────
        let mut conv_weight = self.conv.clone();
        if conv_weight.dims().len() == 3 {
            // [hidden, 1, l_cache] → [hidden, l_cache]
            conv_weight = conv_weight.squeeze(1)?;
        } else if conv_weight.dims().len() == 2
            && conv_weight.dims2()? == (self.l_cache, hidden)
        {
            // [l_cache, hidden] → [hidden, l_cache]
            conv_weight = conv_weight.t()?.contiguous()?;
        }
        let conv_weight = conv_weight.contiguous()?;

        // ── Decode (seq_len == 1) vs Prefill (seq_len > 1) ───────
        let mut conv_out = if seq_len == 1 {
            // Decode step: roll the state buffer
            let mut state = if let Some(cache) = &self.cache {
                cache.clone()
            } else {
                Tensor::zeros((b_sz, hidden, self.l_cache), bx.dtype(), bx.device())?
            };

            if self.l_cache > 1 {
                let tail = state.narrow(2, 1, self.l_cache - 1)?;
                state = Tensor::cat(&[tail, bx.clone()], 2)?;
            } else {
                state = bx.clone();
            }
            self.cache = Some(state.clone());

            // Element-wise multiply then sum over the kernel dimension
            (state * &conv_weight.unsqueeze(0)?)?
                .sum_keepdim(2)?
                .contiguous()?
        } else {
            // Prefill: depthwise Conv1d with causal padding
            let conv = Conv1d::new(
                conv_weight
                    .reshape((hidden, 1, self.l_cache))?
                    .contiguous()?,
                None,
                Conv1dConfig {
                    padding: self.l_cache.saturating_sub(1),
                    groups: hidden,
                    ..Default::default()
                },
            );
            let mut out = conv.forward(&bx.contiguous()?)?;
            // Trim to exactly seq_len (causal padding adds l_cache-1 extra)
            out = out.narrow(2, 0, seq_len)?;

            // Save the last l_cache frames for the next decode step
            if self.l_cache > 0 {
                let (_, _, cur_len) = bx.dims3()?;
                let start = cur_len.saturating_sub(self.l_cache);
                let mut cache_src = bx.narrow(2, start, cur_len - start)?;
                if cache_src.dims3()?.2 < self.l_cache {
                    let pad = self.l_cache - cache_src.dims3()?.2;
                    let zeros = Tensor::zeros(
                        (b_sz, hidden, pad),
                        cache_src.dtype(),
                        cache_src.device(),
                    )?;
                    cache_src = Tensor::cat(&[zeros, cache_src], 2)?;
                }
                self.cache = Some(cache_src);
            }

            out
        };

        // ── Output gate (c) ──────────────────────────────────────
        // c comes out as [B, H, S] from the narrow above; make sure dims match.
        let c = if c.dims().len() == 2 {
            c.unsqueeze(2)?
        } else {
            c
        };

        // conv_out should be 3-D; squeeze a stray dim if needed.
        let conv_out_fixed = if conv_out.dims().len() == 4 {
            conv_out.squeeze(2)?
        } else {
            conv_out
        };

        conv_out = (c.broadcast_as(conv_out_fixed.shape())? * &conv_out_fixed)?;

        // [B, H, S] → [B, S, H] then project
        let conv_out = conv_out.transpose(1, 2)?.contiguous()?;
        self.out_proj.forward(&conv_out)
    }
}

// ── Top-level model ───────────────────────────────────────────────────────────

pub struct ModelWeights {
    tok_embeddings: Embedding,
    layers: Vec<LayerWeights>,
    norm: RmsNorm,
    output: QMatMul,
    masks: HashMap<usize, Tensor>,
    span: tracing::Span,
    span_output: tracing::Span,
}

// ── GGUF metadata helpers ─────────────────────────────────────────────────────

fn value_to_usize(v: &gguf_file::Value) -> Result<usize> {
    use gguf_file::Value::*;
    match v {
        U8(x)   => Ok(*x as usize),
        I8(x)   => Ok(*x as usize),
        U16(x)  => Ok(*x as usize),
        I16(x)  => Ok(*x as usize),
        U32(x)  => Ok(*x as usize),
        I32(x)  => Ok(*x as usize),
        U64(x)  => Ok(*x as usize),
        I64(x)  => Ok(*x as usize),
        F32(x)  => Ok(*x as usize),
        F64(x)  => Ok(*x as usize),
        Bool(x) => Ok(usize::from(*x)),
        String(_) => bail!("unexpected string metadata"),
        Array(_)  => bail!("array should be handled separately"),
    }
}

fn read_usize_list(v: &gguf_file::Value, len: usize) -> Result<Vec<usize>> {
    use gguf_file::Value::Array;
    match v {
        Array(arr) => {
            let mut out = Vec::with_capacity(arr.len());
            for item in arr {
                out.push(value_to_usize(item)?);
            }
            if out.len() == len {
                Ok(out)
            } else if out.len() == 1 {
                Ok(vec![out[0]; len])
            } else {
                bail!(
                    "unexpected array length in metadata, expected {len} got {}",
                    out.len()
                )
            }
        }
        _ => Ok(vec![value_to_usize(v)?; len]),
    }
}

// ── ModelWeights impl ─────────────────────────────────────────────────────────

impl ModelWeights {
    /// Clear all KV / conv caches (call before a fresh prefill).
    pub fn clear_kv_cache(&mut self) {
        for layer in self.layers.iter_mut() {
            match &mut layer.kind {
                LayerKind::Attention(attn) => attn.kv_cache = None,
                LayerKind::ShortConv(conv) => conv.cache   = None,
            }
        }
    }

    /// Snapshot every layer's cache so we can restore it later.
    pub fn snapshot_kv_cache(&self) -> Vec<(Option<(Tensor, Tensor)>, Option<Tensor>)> {
        self.layers
            .iter()
            .map(|layer| match &layer.kind {
                LayerKind::Attention(attn) => (attn.kv_cache.clone(), None),
                LayerKind::ShortConv(conv) => (None, conv.cache.clone()),
            })
            .collect()
    }

    /// Restore a previously snapshotted cache (e.g. the system-prompt cache).
    pub fn restore_kv_cache(
        &mut self,
        cache: &[(Option<(Tensor, Tensor)>, Option<Tensor>)],
    ) {
        for (layer, state) in self.layers.iter_mut().zip(cache) {
            match &mut layer.kind {
                LayerKind::Attention(attn) => attn.kv_cache = state.0.clone(),
                LayerKind::ShortConv(conv) => conv.cache   = state.1.clone(),
            }
        }
    }

    /// Load weights from a GGUF file.
    pub fn from_gguf<R: std::io::Seek + std::io::Read>(
        ct: gguf_file::Content,
        reader: &mut R,
        device: &Device,
    ) -> Result<Self> {
        let md_get = |s: &str| match ct.metadata.get(s) {
            None    => bail!("cannot find {s} in metadata"),
            Some(v) => Ok(v),
        };

        // ── Hyper-parameters ─────────────────────────────────────
        let head_count         = md_get("lfm2.attention.head_count")?.to_u32()? as usize;
        let head_count_kv_meta = md_get("lfm2.attention.head_count_kv")?;
        let embedding_length   = md_get("lfm2.embedding_length")?.to_u32()? as usize;
        let context_length     = md_get("lfm2.context_length")?.to_u32()? as usize;
        let block_count        = md_get("lfm2.block_count")?.to_u32()? as usize;
        let rms_norm_eps       = md_get("lfm2.attention.layer_norm_rms_epsilon")?.to_f32()? as f64;
        let rope_freq_base     = md_get("lfm2.rope.freq_base")
            .and_then(|m| m.to_f32())
            .unwrap_or(1_000_000f32);
        let l_cache            = md_get("lfm2.shortconv.l_cache")?.to_u32()? as usize;

        let head_count_kv = read_usize_list(head_count_kv_meta, block_count)?;
        let head_dim      = embedding_length / head_count;

        let (cos, sin) = precomput_freqs_cis(head_dim, rope_freq_base, context_length, device)?;
        let neg_inf    = Tensor::new(f32::NEG_INFINITY, device)?;

        // ── Token embeddings ─────────────────────────────────────
        let tok_embeddings_q = get_qtensor(
            &ct, reader, device,
            &["token_embd.weight", "tok_embeddings.weight", "model.embed_tokens.weight"]
                .iter().map(|s| s.to_string()).collect::<Vec<_>>(),
        )?;
        let tok_embeddings = tok_embeddings_q.dequantize(device)?;
        tracing::debug!(
            tok_embd_shape = ?tok_embeddings.shape().dims(),
            "loaded lfm2 token embeddings"
        );

        // ── Final norm ───────────────────────────────────────────
        let norm = RmsNorm::from_qtensor(
            get_qtensor(
                &ct, reader, device,
                &[
                    "output_norm.weight",
                    "embedding_norm.weight",
                    "model.embedding_norm.weight",
                    "model.embedding_norm",
                    "token_embd_norm.weight",
                ].iter().map(|s| s.to_string()).collect::<Vec<_>>(),
            )?,
            rms_norm_eps,
        )?;

        // ── LM head (fall back to tied embeddings) ───────────────
        let output_q = get_qtensor(
            &ct, reader, device,
            &["output.weight", "lm_head.weight", "model.output.weight", "model.lm_head.weight"]
                .iter().map(|s| s.to_string()).collect::<Vec<_>>(),
        )
        .unwrap_or(tok_embeddings_q);
        tracing::debug!(
            output_shape = ?output_q.shape().dims(),
            "loaded lfm2 output weight (using tok_embd if missing)"
        );

        // ── Per-block weights ────────────────────────────────────
        let mut layers = Vec::with_capacity(block_count);

        for layer_idx in 0..block_count {
            let prefix       = format!("blk.{layer_idx}");
            let is_attention = head_count_kv
                .get(layer_idx)
                .copied()
                .unwrap_or(head_count) > 0;

            // Shared norms
            let operator_norm = get_qtensor(
                &ct, reader, device,
                &[
                    format!("{prefix}.attn_norm.weight"),
                    format!("{prefix}.operator_norm.weight"),
                    format!("{prefix}.attention_norm.weight"),
                ],
            )?;
            let ffn_norm = get_qtensor(
                &ct, reader, device,
                &[
                    format!("{prefix}.ffn_norm.weight"),
                    format!("{prefix}.ffn_norm"),
                ],
            )?;

            // Shared MLP
            let mlp = {
                let w1 = get_qtensor(
                    &ct, reader, device,
                    &[
                        format!("{prefix}.ffn_gate.weight"),
                        format!("{prefix}.feed_forward.w1.weight"),
                        format!("{prefix}.mlp.gate_proj.weight"),
                    ],
                )?;
                let w2 = get_qtensor(
                    &ct, reader, device,
                    &[
                        format!("{prefix}.ffn_down.weight"),
                        format!("{prefix}.feed_forward.w2.weight"),
                        format!("{prefix}.mlp.down_proj.weight"),
                    ],
                )?;
                let w3 = get_qtensor(
                    &ct, reader, device,
                    &[
                        format!("{prefix}.ffn_up.weight"),
                        format!("{prefix}.feed_forward.w3.weight"),
                        format!("{prefix}.mlp.up_proj.weight"),
                    ],
                )?;
                Mlp {
                    w1: QMatMul::from_qtensor(w1)?,
                    w2: QMatMul::from_qtensor(w2)?,
                    w3: QMatMul::from_qtensor(w3)?,
                }
            };

            // Attention or ShortConv operator
            let kind = if is_attention {
                let n_kv_head = head_count_kv[layer_idx];

                let wq = get_qtensor(&ct, reader, device, &[
                    format!("{prefix}.attn_q.weight"),
                    format!("{prefix}.self_attn.q_proj.weight"),
                ])?;
                let wk = get_qtensor(&ct, reader, device, &[
                    format!("{prefix}.attn_k.weight"),
                    format!("{prefix}.self_attn.k_proj.weight"),
                ])?;
                let wv = get_qtensor(&ct, reader, device, &[
                    format!("{prefix}.attn_v.weight"),
                    format!("{prefix}.self_attn.v_proj.weight"),
                ])?;
                let wo = get_qtensor(&ct, reader, device, &[
                    format!("{prefix}.attn_output.weight"),
                    format!("{prefix}.self_attn.out_proj.weight"),
                ])?;
                let q_norm = get_qtensor(&ct, reader, device, &[
                    format!("{prefix}.attn_q_norm.weight"),
                    format!("{prefix}.self_attn.q_layernorm.weight"),
                    format!("{prefix}.attention.q_norm.weight"),
                ])?;
                let k_norm = get_qtensor(&ct, reader, device, &[
                    format!("{prefix}.attn_k_norm.weight"),
                    format!("{prefix}.self_attn.k_layernorm.weight"),
                    format!("{prefix}.attention.k_norm.weight"),
                ])?;

                LayerKind::Attention(AttentionLayer {
                    wq:        QMatMul::from_qtensor(wq)?,
                    wk:        QMatMul::from_qtensor(wk)?,
                    wv:        QMatMul::from_qtensor(wv)?,
                    wo:        QMatMul::from_qtensor(wo)?,
                    q_norm:    RmsNorm::from_qtensor(q_norm, rms_norm_eps)?,
                    k_norm:    RmsNorm::from_qtensor(k_norm, rms_norm_eps)?,
                    n_head:    head_count,
                    n_kv_head,
                    head_dim,
                    cos:       cos.clone(),
                    sin:       sin.clone(),
                    neg_inf:   neg_inf.clone(),
                    kv_cache:  None,
                    span_attn: tracing::span!(tracing::Level::TRACE, "attn"),
                    span_rot:  tracing::span!(tracing::Level::TRACE, "attn-rot"),
                })
            } else {
                let in_proj = get_qtensor(&ct, reader, device, &[
                    format!("{prefix}.shortconv.in_proj.weight"),
                    format!("{prefix}.conv.in_proj.weight"),
                ])?;
                let out_proj = get_qtensor(&ct, reader, device, &[
                    format!("{prefix}.shortconv.out_proj.weight"),
                    format!("{prefix}.conv.out_proj.weight"),
                ])?;
                let conv = get_dequantized(&ct, reader, device, &[
                    format!("{prefix}.shortconv.conv.weight"),
                    format!("{prefix}.conv.conv.weight"),
                    format!("{prefix}.shortconv.conv"),
                ])?;

                LayerKind::ShortConv(ShortConvLayer {
                    in_proj:  QMatMul::from_qtensor(in_proj)?,
                    out_proj: QMatMul::from_qtensor(out_proj)?,
                    conv,
                    l_cache,
                    cache: None,
                })
            };

            layers.push(LayerWeights {
                operator_norm: RmsNorm::from_qtensor(operator_norm, rms_norm_eps)?,
                ffn_norm:      RmsNorm::from_qtensor(ffn_norm,      rms_norm_eps)?,
                mlp,
                kind,
                span_mlp: tracing::span!(tracing::Level::TRACE, "ffn"),
            });
        }

        Ok(Self {
            tok_embeddings: Embedding::new(tok_embeddings, embedding_length),
            layers,
            norm,
            output: QMatMul::from_qtensor(output_q)?,
            masks: HashMap::new(),
            span:        tracing::span!(tracing::Level::TRACE, "model"),
            span_output: tracing::span!(tracing::Level::TRACE, "output"),
        })
    }

    /// Build (and cache) a square causal mask of size `t × t`.
    fn mask(&mut self, t: usize, device: &Device) -> Result<Tensor> {
        if let Some(mask) = self.masks.get(&t) {
            return Ok(mask.clone());
        }
        let mask: Vec<_> = (0..t)
            .flat_map(|i| (0..t).map(move |j| u8::from(j > i)))
            .collect();
        let mask = Tensor::from_slice(&mask, (t, t), device)?;
        self.masks.insert(t, mask.clone());
        Ok(mask)
    }

    /// Run a forward pass.
    ///
    /// `x`         – token ids, shape [batch, seq_len]
    /// `index_pos` – position of the first token in `x` (0 for the initial
    ///               prefill, `sys_pos + turn_len` for decode steps)
    pub fn forward(&mut self, x: &Tensor, index_pos: usize) -> Result<Tensor> {
        let (_b_sz, seq_len) = x.dims2()?;

        // Only build the causal mask for multi-token (prefill) passes.
        // Single-token decode steps don't need masking.
        let mask = if seq_len == 1 {
            None
        } else {
            Some(self.mask(seq_len, x.device())?)
        };

        let _enter  = self.span.enter();
        let mut hidden = self.tok_embeddings.forward(x)?;

        for layer in self.layers.iter_mut() {
            // ── Operator (attention / conv) ──────────────────────
            let residual = hidden.clone();
            let normed   = layer.operator_norm.forward(&hidden)?;
            hidden = match &mut layer.kind {
                LayerKind::Attention(attn) => attn.forward(&normed, mask.as_ref(), index_pos)?,
                LayerKind::ShortConv(conv) => conv.forward(&normed, index_pos)?,
            };
            hidden = (hidden + residual)?;

            // ── FFN ──────────────────────────────────────────────
            let residual    = hidden.clone();
            let ff          = layer.ffn_norm.forward(&hidden)?;
            let _enter_mlp  = layer.span_mlp.enter();
            let ff          = layer.mlp.forward(&ff)?;
            hidden          = (ff + residual)?;
        }

        // Final norm + extract last token for LM head
        let hidden = self.norm.forward(&hidden)?;
        let hidden = hidden.i((.., seq_len - 1, ..))?;

        let _enter = self.span_output.enter();
        self.output.forward(&hidden)
    }
}
# Model Candidates for AURA — Sub-1B & ~1B Instruct Models

Researched: 2026-06-30 | Source: HuggingFace, LM Studio

---

## Current Models (LFM2.5)

| Model | Params | Q4 Size | Speed | Persona | Recall | Issue |
|-------|--------|---------|-------|---------|--------|-------|
| LFM2.5-230M-Q4_K_M | 230M | 153 MB | 50-55 tok/s | 0/6 | 2/4 (injected) | Breaks character, says "as an AI" |
| LFM2.5-1.2B-Instruct-Q4_K_M | 1.2B | 698 MB | 10-12 tok/s | 6/6 | 0.5/4 (injected) | Ignores injected memory, too poetic |

---

## Top Candidates (ranked)

### 1. Llama-3.2-1B-Instruct (BEST REPLACEMENT for 1.2B)
- **Params**: 1B | **Q4_K_M**: ~638 MB | **Downloads**: 389k (bartowski)
- **URL**: `huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF`
- **Chat template**: Llama-3 ChatML (close to LFM's `<|im_start|>`)
- **Pros**: Meta-trained, excellent instruction following, huge community, proven persona consistency, strong fact recall
- **Cons**: Slightly larger than LFM 1.2B in memory but faster (standard transformer, not recurrent)
- **Why it's better**: Llama-3.2 was specifically trained for instruction following and persona consistency. It won't say "as an AI" — Meta's RLHF explicitly trained against that. It also handles injected context better than LFM's recurrent architecture.

### 2. Qwen2.5-0.5B-Instruct (BEST REPLACEMENT for 230M)
- **Params**: 0.5B | **Q4_K_M**: ~400 MB | **Downloads**: 198k (Qwen official)
- **URL**: `huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF`
- **Chat template**: Qwen ChatML (`<|im_start|>` — same as LFM!)
- **Pros**: Same chat template as LFM (zero code changes), excellent instruction following at 0.5B, fast, Alibaba-trained with strong persona
- **Cons**: 400 MB vs 153 MB (still fits in assets)
- **Why it's better**: Qwen2.5-0.5B was trained with ChatML format — exact same `<|im_start|>` tokens as LFM2.5. This means the existing system prompt, persona examples, and KV cache logic work without any code changes. At 0.5B it should be fast (30-40 tok/s estimated) AND maintain persona.

### 3. Qwen2.5-1.5B-Instruct (ALTERNATIVE for 1.2B)
- **Params**: 1.5B | **Q4_K_M**: ~890 MB | **Downloads**: 245k
- **URL**: `huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF`
- **Pros**: Same ChatML format, best instruction following in class, strong reasoning
- **Cons**: 890 MB — larger than LFM 1.2B (698 MB), slower on CPU

### 4. SmolLM2-360M-Instruct (EXPERIMENTAL — smallest)
- **Params**: 360M | **Q4_K_M**: ~240 MB | **Downloads**: 46
- **URL**: `huggingface.co/itlwas/SmolLM2-360M-Instruct-Q4_K_M-GGUF`
- **Pros**: HuggingFace-trained, very small, fast
- **Cons**: Low downloads, untested at scale, may have weak persona

---

## Recommendation

**Replace LFM2.5 with Qwen2.5 family** — same ChatML format, zero code changes needed:

| Slot | Current | Recommended | Why |
|------|---------|-------------|-----|
| Small/fast | LFM2.5-230M (153MB) | Qwen2.5-0.5B (400MB) | Same ChatML, much better persona, still fast |
| Large/quality | LFM2.5-1.2B (698MB) | Llama-3.2-1B (638MB) or Qwen2.5-1.5B (890MB) | Better instruction following, no "as an AI" leakage |

**For the paper**: Test all 4 models (LFM 230M, LFM 1.2B, Qwen 0.5B, Llama-3.2-1B) with the same 30-case test suite. The ablation compares:
- Model architecture (recurrent LFM vs standard transformer Qwen/Llama)
- Model size (0.5B vs 1B vs 1.2B)
- Memory approach (blind vs injection vs fast-path)

---

## Download URLs (Q4_K_M)

```
Qwen2.5-0.5B:  huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf
Llama-3.2-1B:  huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf
Qwen2.5-1.5B:  huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf
SmolLM2-360M:  huggingface.co/itlwas/SmolLM2-360M-Instruct-Q4_K_M-GGUF/resolve/main/smollm2-360m-instruct-q4_k_m.gguf
```

## Tokenizer URLs

```
Qwen2.5:       huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/resolve/main/tokenizer.json
Llama-3.2:     huggingface.co/meta-llama/Llama-3.2-1B-Instruct/resolve/main/tokenizer.json
```

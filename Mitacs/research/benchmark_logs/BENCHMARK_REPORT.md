# AURA LNN Performance Benchmark Report

Date: 2026-06-25 21:15:44

## 1. Runtime Verification

- **tokio**: Working
- **rayon**: Working

## 2. Model & System Info

- Model: `../../aura_notebook/assets/LFM2.5-230M-Q4_K_M.gguf`
- Device: CPU (Cortex-A55 + NEON dotprod)

## 3. Warmup Performance

- Cold: **0.78s**
- Warm: **0.80s**

## 4. KV Cache I/O

- Load: **0.80s**
- Size: **17.7 MB**

## 5. Inference Performance

| Prompt | TTFT | Tokens | Total | tok/s |
|--------|------|--------|-------|-------|
| Short chat | 34ms | 198 | 2341ms | 84.6 |
| Medium query | 42ms | 204 | 2531ms | 80.6 |
| Emotional | 42ms | 426 | 6319ms | 67.4 |
| Instruction | 55ms | 126 | 2009ms | 62.7 |

**Aggregate**: 954 tokens in 13.20s -> **72.3 tok/s**

## 6. Cache Reuse

- Hit: **39ms** | Miss: **1041ms** | Speedup: **26.6x**

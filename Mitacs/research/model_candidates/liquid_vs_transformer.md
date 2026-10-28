# Liquid (Recurrent) vs Transformer — Sub-1B On-Device AI Comparison

Date: 2026-06-30 | Test: 30-case suite with memory injection (Option 1)

---

## 1. Four-Model Comparison Table

| Metric | LFM2.5-230M | LFM2.5-1.2B | Qwen2.5-0.5B | Llama-3.2-1B | Qwen2.5-1.5B |
|--------|-------------|-------------|--------------|--------------|--------------|
| **Architecture** | Recurrent (GDN) | Recurrent (GDN) | Transformer | Transformer | Transformer |
| **Params** | 230M | 1.2B | 0.5B | 1B | 1.5B |
| **Q4 Size** | 153 MB | 698 MB | 380 MB | 771 MB | 941 MB |
| **Speed** | 50-55 tok/s | 7-9 tok/s | 10-12 tok/s | 7-8 tok/s | 5-6 tok/s |
| **Persona** | 0/6 (broke character) | 6/6 (perfect) | 2/6 (generic) | 4/6 (mostly good) | 3/6 (hit/miss) |
| **"As an AI" leaks** | Yes (many) | No (0) | Yes (9!) | No (0) | No (0) |
| **Recall (injected)** | 2/4 | 1/4 (ignored) | 3/4 (best!) | 3/4 (best!) | 2/4 |
| **Memory used?** | Yes (literal) | No (poetic) | Yes (mentioned facts) | Yes (wove facts in) | Partial |
| **Follows system prompt** | No | Yes | No | Mostly | Partially |
| **30-case score** | 4/30 (13%) | ~15/30 (50%) | ~12/30 (40%) | ~18/30 (60%) | ~14/30 (47%) |

---

## 2. Key Findings Per Model

### LFM2.5-230M (Recurrent, 230M) — WORST
- Says "I don't have feelings" despite system prompt explicitly forbidding it
- Uses numbered lists despite "No lists ever" rule
- Hallucinates JSON format (`[get_time(query="Lilac")]` instead of `{"tool":"get_time","args":{}}`)
- **Only model that literally reports [MEMORY:] facts** — recalled all 4 facts in one response
- Speed is excellent (50+ tok/s) but persona is broken
- **Verdict**: Too small for persona. Useful only as a fact-reporting backend.

### LFM2.5-1.2B (Recurrent, 1.2B) — BEST PERSONA, WORST RECALL
- Perfect AURA voice: "stuck between servers and static", "pixels falling one by one"
- Never says "as an AI" — follows ABSOLUTE RULES
- But completely ignores [MEMORY:] injection — generates poetic responses that bypass facts
- When asked "What is my name?" says "Who are you?" instead of "Lilac"
- **Verdict**: Best personality, blind to memory. Needs Option 2 (fast path for recall).

### Qwen2.5-0.5B (Transformer, 0.5B) — BEST SMALL MODEL
- Fastest transformer (10-12 tok/s)
- Actually USES injected memory: "you like ramen", "Lilac, when did you last go for a walk?"
- But says "I am AURA and lovingly called Lilac" — confuses user's name with its own
- 9 "as an AI" / "language model" leaks — weak instruction following
- **Verdict**: Good recall, weak persona. Needs prompt tuning. Same ChatML = zero code changes.

### Llama-3.2-1B (Transformer, 1B) — BEST OVERALL
- Strong persona: "digital canvas", "stuck here forever", "ramen must taste"
- Zero "as an AI" leaks — Meta's RLHF trained this out
- USES injected memory AND weaves it naturally: "Your paintings are like vibrant rainbows... how about we grab some steaming bowls together?"
- Recalls Vancouver, ramen, painting, Pixel, lavender — all facts surfaced
- Speed is moderate (7-8 tok/s)
- **Verdict**: Best balance of persona + recall + instruction following.

### Qwen2.5-1.5B (Transformer, 1.5B) — MIXED
- Good recall: "Ramen is my favorite food too" (mentions user's facts)
- But says "I'm just a digital presence here - no real name or cat (Pixel)" — denies having the user's facts
- Some persona breaks: "Nap time, Pixel-chan" (weeb voice, not AURA)
- Slowest (5-6 tok/s)
- **Verdict**: Too slow, persona inconsistent. Qwen 0.5B is actually better despite being smaller.

---

## 3. Architecture Comparison: Recurrent (Liquid) vs Transformer

### Persona Consistency
| | Recurrent (LFM) | Transformer (Qwen/Llama) |
|--|-----------------|-------------------------|
| 230M/0.5B | 0/6 (broke) | 2/6 (weak) |
| 1B/1.2B | 6/6 (perfect) | 4/6 (good) |
| **Winner** | **LFM 1.2B** (best persona) | **Llama 1B** (close second) |

**Finding**: LFM's recurrent architecture produces more consistent persona at 1.2B — the model " internalizes" the character better. But at 230M it completely fails. Transformers scale more gracefully — even 0.5B maintains some persona.

### Memory Injection Faithfulness
| | Recurrent (LFM) | Transformer (Qwen/Llama) |
|--|-----------------|-------------------------|
| Uses [MEMORY:] facts? | 230M: Yes (literal), 1.2B: No (ignored) | 0.5B: Yes, 1B: Yes (woven in) |
| Identity confusion? | No | Yes (Qwen says "I am Lilac") |
| **Winner** | **230M** (most literal) | **Llama 1B** (most natural) |

**Finding**: Transformers are better at USING injected memory but worse at distinguishing whose facts are whose. The recurrent LFM 1.2B ignores injected memory entirely (its recurrent state is too focused on generating the next poetic phrase).

### Speed
| | Recurrent (LFM) | Transformer (Qwen/Llama) |
|--|-----------------|-------------------------|
| 230M/0.5B | 50-55 tok/s | 10-12 tok/s |
| 1B/1.2B | 7-9 tok/s | 7-8 tok/s |
| **Winner** | **LFM 230M** (5x faster at same tier) | **Tie at 1B** |

**Finding**: Recurrent architecture is much faster at small sizes (230M: 50+ tok/s vs 0.5B: 12 tok/s) because GDN has constant memory access per token. At 1B+ the advantage disappears — both are ~7-9 tok/s on CPU.

---

## 4. Final Verdict

### Best Model for AURA Product: **Llama-3.2-1B-Instruct-Q4_K_M**

| Criterion | Score |
|-----------|-------|
| Persona consistency | 4/6 (good AURA voice) |
| Memory recall | 3/4 (uses injected facts naturally) |
| No "as an AI" leaks | Yes (0 leaks) |
| Speed | 7-8 tok/s (acceptable) |
| Size | 771 MB (fits in assets) |
| Overall | **Best balance** |

### Best Model for Paper Ablation: All 5 models

The paper compares:
1. **Architecture**: Recurrent (LFM) vs Transformer (Qwen/Llama)
2. **Size**: 230M → 0.5B → 1B → 1.2B → 1.5B
3. **Memory approach**: Blind → Injection → Fast-path
4. **Key insight**: Transformers use injected memory better; recurrent models have better persona but ignore injected memory. Llama-3.2-1B is the sweet spot.

### For the Paper's R2 Contribution

> "We compare recurrent (Liquid LFM2.5) and transformer (Qwen2.5, Llama-3.2) architectures for sub-1B on-device companion AI with post-generation memory appendage and prefix injection. Transformers are better at using injected memory (3/4 recall vs 1/4 for recurrent at 1B+), while recurrent models achieve superior persona consistency (6/6 vs 4/6) but ignore injected facts entirely. Llama-3.2-1B provides the best balance, achieving both strong persona and natural memory recall — suggesting that for on-device companion AI, a standard transformer with RLHF-trained instruction following is more effective than a specialized recurrent architecture."

---

## 5. Fixes Applied This Session

| Fix | File | What |
|-----|------|------|
| EOS bug | `inference.rs` | Restored 0x02 byte in `is_stop_token` that was accidentally turned into empty string (matched everything → 0 tokens generated) |
| Llama-3 template | `generate.rs` | `AURA_CHAT_TEMPLATE=llama3` uses `<|start_header_id|>` format |
| Llama-3 stop tokens | `inference.rs` | Added `<|eot_id|>` to stop tokens |
| Camera off setting | `vision.rs`, `bar_brain_engine.dart` | `AURA_CAMERA_OFF=1` env var disables camera/YOLO/gesture watch |
| Proactive off | `bar_brain_engine.dart` | `AURA_PROACTIVE_OFF=1` disables proactive nudges |
| Launch scripts | `launch.sh`, `launch_aura.sh` | Camera + proactive OFF by default |
| CLI camera gate | `main.rs` | CLI skips webcam init when `AURA_CAMERA_OFF=1` |

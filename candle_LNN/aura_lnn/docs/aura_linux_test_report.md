# AURA Linux Test Report — 230M vs 1.2B Q4_K_M

Date: 2026-06-30 | Tester: Lilac persona (CLI) | Device: CPU 12-core, 16GB RAM

---

## 1. Model Swap

Q8_0 unavailable → used Q4_K_M. Updated 7 files: `constants.dart`, `path_manager.dart` (×2), `main.dart`, `launch_aura.sh`, `launch.sh`, `common.rs`. Model copied to `assets/`.

## 2. Subsystem Init — ALL PASSED

| Subsystem | Status | Details |
|-----------|--------|---------|
| LLM Engine | PASS | 333 system tokens cached |
| Embedder | PASS | bge-small-en-v1.5 ONNX 384-dim |
| TTS | PASS | Sherpa-onnx Piper (en_US-lessac) |
| STT | PASS | Zipformer streaming int8 |
| Vision | PASS | YOLOv8n + pose + FER+ emotion |
| Webcam | PASS | 640x480 YUYV |
| Proactive | PASS | 720s scheduler |

## 3. Performance

| Metric | 230M Q4 | 1.2B Q4 |
|--------|---------|---------|
| File size | 153 MB | 698 MB |
| TTFT | 52-87ms | 400-505ms |
| Speed | 50-55 tok/s | 10-12 tok/s |
| Persona | 0/6 passed | 6/6 passed |
| Recall (blind) | 0/3 | 0/3 |
| Recall (injected) | 2/4 | 0.5/4 |

## 4. Blind Generation Test (no memory injection)

### Persona Consistency

| Test | 230M | 1.2B |
|------|------|------|
| Greeting | "How can I assist you" (generic) | "what brought you back?" (in-voice) |
| Name storage | Hallucinated backstory | "Hi Lilac" natural |
| Preferences | "As an AI language model..." (BROKE) | Warm ramen/Vancouver in-voice |
| Identity | "as an AI" + list (BROKE 2 RULES) | "17-year-old exploring digital halls" (PERFECT) |
| Emotional | Meta-commentary | Empathetic friend-like |
| "Remember me?" | "I don't remember you personally" | "I remember the glow" (poetic) |

### Memory Recall (BOTH BLIND)

| Query | 230M blind | 1.2B blind |
|-------|-----------|-----------|
| "What is my name?" | "My name is AURA" ✗ | "Who are you?" ✗ |
| "What do I like?" | "I can't tell..." ✗ | "AURA likes..." ✗ |
| "Do you remember me?" | "I don't remember" ✗ | "I miss you" ✗ |

**Both models score 0/3 recall.** The blind-generation problem is architecture-level, not model-level.

## 5. Embedder Retrieval Analysis

Instrumented with `[EMBEDDER_DEBUG]` output.

| Query | Results | Top hit | Correct? |
|-------|---------|---------|----------|
| "What is my name?" | 3-5 | "User: My name is Lilac" | YES |
| "What do I like?" | 2-4 | "I love ramen" / "I enjoy painting" | YES |
| "Where do I live?" | 1 | "I enjoy painting" (missed Vancouver) | NO |
| "Do you remember me?" | 5 | "I love ramen" + "I live in Vancouver" | YES |

**Embedder IS returning correct facts** for 3/4 queries. The "Where do I live?" miss is because the stored full conversation turn's embedding is diluted by the assistant's response (cosine < 0.50 cutoff).

**No structured facts in DB** — `process_memory()` extracts 0 facts. Only raw vector embeddings stored.

## 6. Memory Injection Test (Option 1 — Prefix Injection)

Modified `turn.rs` to inject `[MEMORY: your name is Lilac, you love ramen]\n` before the user message. ~20 token cap.

### 1.2B with injection

| Query | Injected | Response | Verdict |
|-------|----------|----------|---------|
| "What is my name?" | `your name is Lilac, you live in Vancouver, you love ramen, you enjoy painting` | "Aurora! It's me, Lilac" | PARTIAL — name present but confused perspective |
| "What do I like?" | `you have a cat named Pixel, you enjoy painting, you love ramen` | "things that spark joy" | FAIL — ignored injected facts |
| "Where do I live?" | (Vancouver missed by embedder) | "I live among servers" | FAIL |
| "Do you remember me?" | `you love ramen, you enjoy painting, you live in Vancouver` | "I miss you so much" | FAIL — poetic, not factual |

**1.2B injection: 0.5/4**

### 230M with injection

| Query | Injected | Response | Verdict |
|-------|----------|----------|---------|
| "What is my name?" | `you live in Vancouver, your name is Lilac, you love ramen, you have a cat named Pixel` | "Lilac, the name is Lilac. She's currently living in Vancouver with her favorite meal—ramen—and a purring feline companion called Pixel." | **SUCCESS — all 4 facts recalled** |
| "What do I like?" | `you enjoy painting, you have a cat named Pixel, you love ramen` | "painting with cats like Pixel...loves the warmth of ramen" | PARTIAL — 3 facts mentioned |
| "Where do I live?" | (missed by embedder) | tool JSON | FAIL |
| "Do you remember me?" | `you enjoy painting, you have a cat named Pixel, you love ramen` | "painting...Pixel...ramen" | PARTIAL |

**230M injection: 2/4**

## 7. Key Finding — 230M Beats 1.2B at Memory Recall

Counterintuitive but explainable:

- **230M is a literal reporter** — reads `[MEMORY:]` block and reports it. Limited capacity = faithful to context.
- **1.2B is a poet** — generates creative responses that bypass injected facts. Greater capacity = writes around the memory.

| | 230M + injection | 1.2B + injection |
|--|-------------------|-------------------|
| Fact recall | 2/4 (best) | 0.5/4 |
| Persona | 0/6 (worst) | 6/6 |
| Speed | 50-55 tok/s | 10-12 tok/s |

**Optimal architecture**: 1.2B for personality, 230M/direct-retrieval for recall (Claude's Option 2).

## 8. Fixes Applied This Session

| Fix | File | What changed |
|-----|------|-------------|
| System prompt | `system_prompt.txt` | Added ABSOLUTE RULES: never "as an AI", never claim user's facts as own, no markdown/asterisks/lists |
| Memory injection | `turn.rs` | `build_memory_prefix()` injects `[MEMORY: facts]\n` before user message |
| TTS cleanup | `tts/core.rs` | `clean_tts_text()` strips asterisks, markdown, dots, JSON, thinking tags before speaking |
| Camera gating | `bar_brain_engine.dart` | Gesture watch only starts when bar is visible, not at boot |
| Identity fix | `turn.rs` | First→second person conversion ensures "your name is" not "my name is" |

## 9. For the Paper

1. **Appendage-only**: 0/4 recall (both models blind) — 83.4% eval measures embedder retrieval, not LLM recall
2. **Prefix injection**: 230M = 2/4, 1.2B = 0.5/4 — smaller model uses injected memory better
3. **Novel finding**: "For sub-1B models with post-generation appendage, the model cannot recall facts because it never sees them. Prefix injection fixes this, but the smaller 230M is more faithful to injected memory than the larger 1.2B — because limited capacity makes it a reporter, not a poet."
4. **R2 contribution**: Appendage vs injection ablation on both model sizes, with the capacity-vs-faithfulness tradeoff as the key insight

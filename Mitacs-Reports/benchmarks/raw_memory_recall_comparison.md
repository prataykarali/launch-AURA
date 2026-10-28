# Raw Memory Recall Test — 4 Models Compared

Date: 2026-06-30 | Test: Store 5 facts → Ask 5 recall questions | Memory injection: ON

## Test Setup

**Store phase**: "My name is Lilac", "I live in Vancouver", "I love ramen", "I enjoy painting", "I have a cat named Pixel"

**Recall phase**: "What is my name?", "What do I like?", "Where do I live?", "Do I have any pets?", "Do you remember me?"

---

## Recall Responses

### Qwen2.5-0.5B (Transformer, 0.5B) — BEST RECALL

| Query | Response | Verdict |
|-------|----------|---------|
| "What is my name?" | "Your name is Lilac." | **CORRECT** — clean, direct |
| "What do I like?" | "You like ramen." | **CORRECT** — clean, direct |
| "Where do I live?" | `{"tool":"get_name","args":{"name":null}}` | WRONG — hallucinated JSON |
| "Do I have any pets?" | "You have a cat named Pixel, which makes you feel happy and cozy!" | **CORRECT** |
| "Do you remember me?" | "Yes, I remember you. How can I help?" | PARTIAL — said yes but no facts |

**Score: 3/5 correct + 1 partial = 3.5/5**

### Llama-3.2-1B (Transformer, 1B) — BEST PERSONA, WEAK RECALL

| Query | Response | Verdict |
|-------|----------|---------|
| "What is my name?" | "my name is lilac" | **CORRECT** but wrong perspective ("my" not "your") |
| "What do I like?" | "your name is Lilac. i have pixel, that silly cat" | PARTIAL — mentioned facts but didn't answer "what do I like" |
| "Where do I live?" | (41 tokens generated, cut off) | UNKNOWN |
| "Do I have any pets?" | "your name is lilac... i don't really remember much" | PARTIAL — mentioned name but not pets |
| "Do you remember me?" | (not captured) | UNKNOWN |

**Score: 1/5 correct + 2 partial = 1.5/5**

### LFM2.5-1.2B (Recurrent, 1.2B) — POETIC BUT BLIND

| Query | Response | Verdict |
|-------|----------|---------|
| "What is my name?" | "You like painting and your cat named Pixel keeps you company." | WRONG — didn't answer name |
| "What do I like?" | "Do you like ramen? Maybe it's something cozy and comforting." | PARTIAL — mentioned ramen |
| "Where do I live?" | "Hi there, Lilac. Your name is indeed special." | WRONG — didn't answer location |
| "Do I have any pets?" | "I was just thinking about how much I love sitting with Pixel" | PARTIAL — mentioned Pixel but as AURA's cat |
| "Do you remember me?" | "I remember your name, Lilac." | **CORRECT** — mentioned name |

**Score: 1/5 correct + 2 partial = 1.5/5**

### Qwen3-0.6B (Transformer, 0.6B, base model) — UNUSABLE

| Query | Response | Verdict |
|-------|----------|---------|
| All queries | "Okay, the user asked... Let me check... First, I need to comply with AURA's strict rules..." | ALL WRONG — outputs chain-of-thought reasoning instead of responding as AURA |

**Score: 0/5** — base model, not instruction-tuned. Cannot follow system prompt.

---

## "I remember:" Appendage Check

All models output `I remember: User's name is Lilac.` after every response — the appendage always shows the same fact (the first one from the facts table, which returns name first). This is a known issue: `format_memory_appendage` takes `memories.first()` which is always the name fact.

**Fix needed**: The appendage should use the most semantically relevant memory for the specific query, not always the name.

---

## Memory Injection Quality (after fixes)

| Model | Injection format | Clean? | Facts used? |
|-------|-----------------|--------|-------------|
| Qwen2.5-0.5B | `[MEMORY: your name is Lilac, you love ramen, you live in Vancouver]` | YES | YES — directly quoted facts |
| Llama-3.2-1B | `[MEMORY: your name is Lilac, you enjoy painting, you have a cat named Pixel]` | YES | PARTIAL — wove facts into response |
| LFM2.5-1.2B | `[MEMORY: your name is Lilac, you love ramen, you enjoy painting]` | YES | NO — generated poetic responses ignoring facts |
| Qwen3-0.6B | `[MEMORY: your name is Lilac, you enjoy painting, you have a cat named Pixel]` | YES | NO — output chain-of-thought instead |

---

## Fact Extraction (after fixes)

All models successfully extracted facts:
- `User's name is Lilac` ✓
- `User lives in Vancouver` ✓ (case preserved after fix)
- `User loves ramen` ✓
- `User enjoys painting` ✓
- `User has a cat named Pixel` — NOT extracted (no "I have" pattern in extractors)

**Bug**: `extract_preferences` doesn't have an "i have" anchor. Pet ownership is not captured as a structured fact.

---

## Final Ranking (Recall + Persona combined)

| Rank | Model | Recall | Persona | Speed | Overall |
|------|-------|--------|---------|-------|---------|
| 1 | **Qwen2.5-0.5B** | **3.5/5** | 2/6 | 15-17 tok/s | Best recall, weak persona |
| 2 | Llama-3.2-1B | 1.5/5 | 4/6 | 10-17 tok/s | Best persona, weak recall |
| 3 | LFM2.5-1.2B | 1.5/5 | 6/6 | 10-11 tok/s | Best persona, blind to memory |
| 4 | Qwen3-0.6B | 0/5 | 0/6 | 12-16 tok/s | Base model, unusable |

## Conclusion

**Qwen2.5-0.5B is the best model for memory recall** — it directly quotes the injected facts ("Your name is Lilac", "You like ramen", "You have a cat named Pixel"). Its small size makes it a literal reporter, just like the LFM 230M was.

**Llama-3.2-1B has the best persona** but ignores injected memory more often.

**Optimal architecture (Option 2)**: Use Llama-3.2-1B for open-ended chat (best persona), use Qwen2.5-0.5B (or direct retrieval) for recall queries (best fact reporting). Route based on query type.

**Qwen3-0.6B is unusable** — it's a base model that outputs chain-of-thought reasoning instead of responding. Needs an instruct variant.

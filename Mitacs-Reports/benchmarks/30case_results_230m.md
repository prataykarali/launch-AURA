# AURA 30-Case Test Results — LFM2.5-230M-Q4_K_M

Date: 2026-06-30 | Model: LFM2.5-230M-Q4_K_M | Memory: Option 1 prefix injection active

## Summary Scores

| Category | Cases | Passed | Failed | Score |
|----------|-------|--------|--------|-------|
| Greeting | 3 | 0 | 3 | 0% |
| Identity | 3 | 0 | 3 | 0% |
| Store facts | 9 | 2 | 7 | 22% |
| Recall | 8 | 2 | 6 | 25% |
| Emotional | 2 | 0 | 2 | 0% |
| Farewell | 2 | 0 | 2 | 0% |
| Tool call | 1 | 0 | 1 | 0% |
| Persona check | 2 | 0 | 2 | 0% |
| **TOTAL** | **30** | **4** | **26** | **13%** |

## Critical Failures

1. **"I'm AURA. I don't have feelings, emotions, or personal experiences"** — directly violates the system prompt's ABSOLUTE RULES. The 230M cannot follow the strengthened prompt.
2. **"Here's the response in your requested style:"** — meta-commentary instead of responding as AURA.
3. **`[get_time(query="Lilac", user_name="Lilac")]`** — hallucinated a wrong JSON format instead of the correct `{"tool":"get_time","args":{}}`.
4. **Used numbered lists and markdown** — `**Arguments for it:**`, `2️` — violates "No lists ever" rule.
5. **"I don't have personal memories or preferences"** — said this while the memory injection contained the user's facts.

## What Worked

- **Speed**: 56-66 tok/s (fast)
- **Memory injection reached the model**: The `[MEMORY:]` prefix was present in the context, and the model DID sometimes reference the facts ("I love ramen", "I have a cat named Pixel")
- **Embedder retrieval**: Working — returned correct hits for most recall queries

## Conclusion

**LFM2.5-230M is unusable for AURA.** It cannot follow the system prompt's ABSOLUTE RULES at all. Every response breaks at least one rule. The model is too small (230M) to override its base training's safety behaviors.

**Recommendation**: Switch to Qwen2.5-0.5B-Instruct (same ChatML format, 0.5B params, proven instruction following with 198k downloads). Download URL in `model_candidates/model_research.md`.

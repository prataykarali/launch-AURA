# AURA Mitacs Research: Evaluation Framework

## Research Questions

RQ1: Can a 1.2B on-device model with structured memory achieve acceptable companion AI quality?
RQ2: Does the hybrid memory system (sqlite-vec + BM25) improve recall over vector-only search?
RQ3: Does bandit RL improve proactive engagement over fixed-schedule triggers?
RQ4: Does SFT fine-tuning on companion AI data improve persona adherence and response quality?

## Evaluation Metrics

### Quantitative
- Memory recall accuracy (exact match + fuzzy match)
- Response latency (TTFT, tokens/sec)
- Persona boundary compliance (does AURA claim user facts?)
- Response length appropriateness (short for greetings, long for explanations)
- Proactive engagement rate (user responds within 30s)

### Qualitative
- Human-likeness rating (1-5 Likert)
- Warmth rating (1-5 Likert)
- Usefulness rating (1-5 Likert)
- "Would you continue using this?" (yes/no)

## Ablation Studies

### Study 1: Memory Components
| Condition | Vector DB | BM25 | Facts Table | Expected |
|-----------|-----------|------|-------------|----------|
| A (full) | ✓ | ✓ | ✓ | Best recall |
| B (no BM25) | ✓ | ✗ | ✓ | Moderate recall |
| C (no vector) | ✗ | ✓ | ✓ | Lower recall |
| D (no memory) | ✗ | ✗ | ✗ | Hallucination |

### Study 2: RL Components
| Condition | Bandit | Engagement Signal | Expected |
|-----------|--------|-------------------|----------|
| A (full) | ✓ | ✓ | Best engagement |
| B (random) | ✗ | ✓ | Lower engagement |
| C (fixed) | ✗ | ✗ | Baseline |

### Study 3: Model Size
| Condition | Model | Expected |
|-----------|-------|----------|
| A | LFM2.5-1.2B (base) | Baseline |
| B | LFM2.5-1.2B (SFT) | Better persona |
| C | LFM2.5-3B (if available) | Better quality |

## Benchmark Comparison

Compare AURA against:
- Replika (cloud, 7B+)
- Character.ai (cloud, 7B+)
- Pi (cloud, 7B+)
- GPT-4o-mini (cloud, large)

Test prompts: 100 from our dataset (50 recall, 50 conversation)
Metrics: recall accuracy, persona compliance, response quality

## Test Execution Plan

### Phase 1: Automated (Week 1)
- Run 860 tracker test cases
- Run memory_eval on full dataset
- Run integration_test binary
- Collect: pass rates, latency, token counts

### Phase 2: Ablation (Week 2)
- Run Study 1 (memory ablation)
- Run Study 2 (RL ablation)
- Run Study 3 (before/after SFT)
- Collect: comparative metrics

### Phase 3: User Study (Week 3-4)
- 10 participants, 1 week each
- Daily usage logs (messages sent, features used)
- Pre/post survey (SUS, custom companion AI questionnaire)
- Collect: engagement, satisfaction, persona perception

### Phase 4: Benchmark (Week 4)
- Same 100 prompts across all systems
- Blind evaluation by 3 raters
- Collect: comparative quality scores

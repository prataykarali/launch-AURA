# AURA Personal AI Memory Evaluation Report (PREFIX INJECTION)

- Date: unix:1783695400
- Model: `/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/Llama-3.2-1B-Instruct-Q4_K_M.gguf`
- Architecture: **prefix injection** (`[MEMORY: ...]` before user query)
- Dataset: personal_memory_dataset.json (1000 cases / 10 categories)
- Total Cases: 50
- Passed: 27
- Failed: 23
- **Overall Accuracy: 54.00%**
- Suite Run Time: 355.22s
- Matching: Jaro-Winkler fuzzy (threshold=0.82)
- NOTE: Previous 83.4% figure was measured under **appendage** architecture and is obsolete.

## Per-Category Breakdown

| Category | Passed | Accuracy |
|----------|--------|----------|
| general_quality | 20/29 | 69.0% |
| memory_recall | 3/15 | 20.0% |
| persona_adherence | 4/6 | 66.7% |

## Per-Difficulty Breakdown

| Difficulty | Passed | Accuracy |
|------------|--------|----------|
| easy | 11/23 | 47.8% |
| hard | 3/7 | 42.9% |
| medium | 13/20 | 65.0% |

## Failure Mode Analysis

| Mode | Count |
|------|------:|
| keyword_miss | 20 |
| amnesia_claim | 3 |


# Project AURA - Deep Dive: Models & Mitacs Research Sandbox

This document provides a technical deep-dive into Project AURA's model architectures, optimization layers, and the contents of the `Mitacs` research and evaluation sandbox.

---

## 1. Model Subsystem Details

Project AURA employs a dual-model system: a primary Liquid Foundation Model (LFM) for language generation and reasoning, and a localized Bi-Encoder ONNX model for memory embedding and vector search.

### A. Core LLM: Liquid Foundation Model (LFM)
*   **Active Architectures**:
    *   **LFM2.5-1.2B**: Loaded for full desktop deployments.
    *   **LFM2.5-230M**: A smaller 230-million parameter model optimized for mobile targets (Android/iOS) and local benchmark testing.
*   **Format**: GGUF, quantized to `Q4_K_M` (4-bit hybrid quantization).
*   **Model Engine**: Wraps `llama.cpp` using the Rust bindings `llama_cpp_2`.
*   **Architectural Features & Constraints**:
    *   **Recurrent Gated Delta Net**: Unlike standard Transformer architectures, the LFM recurrent state makes memory footprints smaller, but **does not support partial sequence rewinding (speculative prefill)**. Speculative pre-filling was disabled because writing tokens at arbitrary indices caused sequence misalignment errors.
    *   **Linear Latency Scaling (n_past)**: In the Gated Delta Net architecture, per-token decoding latency grows linearly with the length of context history (`n_past`).

#### LFM Optimizations Implemented:
1.  **Proactive Context Reset (Latency Stabilization)**:
    *   To prevent token generation from slowing down as conversations grow (a ramp from 3s to 20s response times), the engine triggers context resets at a **low watermark** (typically $3/4$ of the context window size).
    *   Resets are executed **between turns** (instead of mid-generation), performing a single predictable KV-cache warmup and maintaining a flat token-per-second rate across long sessions.
2.  **Variable-Length Generation Planner**:
    *   Integrates with a `ReplyPlan` planner that assigns complexity levels (0 to 6) based on prompt queries.
    *   Supports continuations via `generate_continue` (which continues token generation from the last `n_past` state without needing to re-decode previous prompt tokens) if a complex answer requires more token headroom.
3.  **Sampler Chain configuration**:
    *   Simple Penalties: Repeat Last N: `64`, Repeat Penalty: `1.1`
    *   Top-K: `40`
    *   Top-P: `0.85`
    *   Temperature: `0.8`

---

### B. Memory Embedder: BGE Text Embedder
*   **Model**: `bge-small-en-v1.5`
*   **Parameters**: 384-dimensional dense vectors.
*   **Engine**: Loaded via a dedicated **ONNX Runtime session** (`BgeTextEmbedder`) in Rust.
*   **Key Optimizations**:
    *   **No Chat Engine Interference**: Replaces old chat-model mean-pooled embedding logic which was slow, noisy, and locked the LLM context.
    *   **Asynchronous Background Worker**: Offloads passage embeddings to an off-thread worker (`spawn_store_embed_worker`). When a chat turn completes, the chat thread enqueues the text into a bounded sync channel (cap 8) and returns instantly. The worker embeds the text and saves it to SQLite `vec_memory` in the background.

---

## 2. Mitacs Research & Evaluation Sandbox

The `Mitacs` folder (`/home/pratay-karali/launch-AURA/Mitacs`) serves as the evaluation suite and research ground for the memory layers, vector database performance, and hardware constraints.

### A. Evaluation Datasets & Python Tooling
*   `personal_memory_dataset.json` & `memory_test_dataset.json`: Evaluates memory recall using 1000 generated test cases covering 10 categories (e.g., identity, preferences, relationship graphs, temporal events).
*   `generate_personal_dataset.py`: Generates the personal profile testing suite.
*   `generate_charts.py`: Generates SVG accuracy charts using matplotlib.
*   `failure_analysis.py`: Analyzes evaluation outputs and extracts failure mode traces.
*   `dashboard.html`: Hosts the local visualization page displaying accuracy metrics.

---

### B. Hardware & Latency Benchmarks (Aspire A515-58GM, Ubuntu)
Logs from `Mitacs/research_notes/benchmarks.md` detail real-world performance metrics:

1.  **L1 Cache (HashMap vs SQLite)**:
    *   Looks up a user name from 20 cached memory facts.
    *   *SQLite Lookup*: **~6.8 µs per query**
    *   *HashMap Lookup*: **~0.25 µs per query**
    *   *Speedup*: **~28x**. Injects a Layer 1 cache into the FFI session start, bypassing SQLite lookups for primary identity items.
2.  **Data Structures & Algorithms (DSA) Micro-benchmarks**:
    *   Evaluates hot audio paths and event schedulers under 100,000 operations in Release mode:
        *   **Ring Buffer** (VecDeque cap 8 for PCM/VAD): **1 ns/op** (Vectorized by compiler)
        *   **Sliding Window** (VecDeque cap 20 for prefill gating): **1 ns/op**
        *   **Priority Queue** (BinaryHeap cap 8 for scheduler): **7–8 ns/op**
3.  **Inference Speeds (LFM-230M on CPU)**:
    *   *Cold Warmup*: 0.78s
    *   *Warm Warmup*: 0.80s
    *   *KV Cache Hit vs Miss*: **39ms vs 1041ms (26.6x Speedup)**
    *   *Average Speed*: **72.3 tokens/s** (ranging from 84.6 tok/s on short queries to 62.7 tok/s on instruction sets).
    *   *TTFT (Time To First Token)*: **34ms to 55ms**.

---

### C. Accuracy Milestones & Failure Mode Analyses
Logs from `personal_memory_report.md` and `vision_and_memory_research.md` track the accuracy improvements:

*   **Milestone B6 (Baseline)**: **71.70% Overall Accuracy** (1000 cases)
    *   *Strengths*: Name and preference recall (~94%).
    *   *Weaknesses*: Multi-fact synthesis (36%), emotional context (33%), and relationship graphs (50%).
*   **Milestone B7 (Optimized)**: **83.20% Overall Accuracy** (500 cases subset)
    *   *Improvements*: Emotional context boosted to **73% (+40%)**, relationship graphs to **71% (+21%)**.

#### Key Drivers of B7 Optimization:
1.  **Verbatim Fact Instruction Injection**:
    *   *Command*: `"Answer using ONLY the facts listed above. Use the EXACT WORDS and NAMES from the facts — do not paraphrase or substitute synonyms."`
    *   *Impact*: Cut down fuzzy Jaro-Winkler evaluation mismatches by preventing synonyms (e.g. "promoted" vs "work").
2.  **Category-Specific Assistant Pre-filling**:
    *   Steers the model before it can issue canned safety disclaimers (e.g., *"I don't have access to personal details..."*):
        *   *Emotional*: `assistant\nYou were feeling `
        *   *Relationship*: `assistant\nBased on what I know, `
        *   *Default*: `assistant\nBased on what I know about you, `
3.  **Hybrid BM25 + Cosine Retrieval**:
    *   Combines lexical keyword indexing with dense vector search, ensuring names and pronouns trigger the correct facts even when vector distances are ambiguous.
4.  **Retrieval Cap Removal**:
    *   Fetches all user facts (10–20 facts) directly rather than capping at top-3, fixing multi-fact synthesis errors.

---

### D. Remaining Failure Mode Classifications
The remaining 16.8% failures fall under:
1.  **System Prompt Bleed (~6%)**: Model sometimes outputs system prompt instructions due to context reset edge cases.
2.  **Paraphrase Mismatches (~5%)**: Fuzzy matcher fails to connect valid synonyms.
3.  **Dataset Noise (~3%)**: Too-specific target keywords.
4.  **Genuine Hallucination (~2%)**.

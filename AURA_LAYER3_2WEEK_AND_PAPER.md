# Layer 3 — 2-week plan + paper you can start today

**One project. One paper. Not nine.**

Layer 3 = Memory / Graph RAG (AKF + two-pass retrieve + no-spam).  
This is the chapter labs care about. The other 8 layers are **related work / systems context** in the same paper, not 8 extra repos.

College-pressure assumption: **~10–14 focused hours / week**, not 80.

---

# A. Exact 2-week plan (Layer 3 only)

## What “done” means (one sentence)

A CLI (or `memory_eval`) that: stores “I have a cat named Mochi” + “I love ramen”, answers “what’s my cat’s name?” with **Mochi only**, answers “hey” with **no biography**, and prints Recall@ask / Spam@chitchat / injected-token count.

If that loop works, you have a paper experiment. The Flutter bar can wait.

## What you already have (do not rebuild)

| Artifact | Use it as |
|----------|-----------|
| `memory_eval`, `memory_test`, hybrid search | baseline harness |
| `personal_memory_dataset.json` | eval set |
| Rule extractor (`worker_utils/rules/*`) | ingestion v0 |
| BGE 384-d ONNX + `vec_memory` | Pass 1 vector |
| `prefix.rs` `[MEMORY:]` | **baseline** to beat |
| Mitacs logs | tables in §Results |

## Week 1 — Baseline + honest numbers + schema (do not invent a new DB)

### Day 1 (2–3 h) — Freeze the baseline

1. Run existing eval **as-is**. Write the numbers in a table labeled **Baseline (always-inject + [MEMORY:])**.
2. Commands (adjust paths if needed):

```bash
cd AURA-Proj/candle_LNN/aura_lnn
cargo run --release --bin memory_eval
# if you use the prefix suite:
# logs already live in Mitacs-Reports/benchmarks/personal_memory_report.md
```

3. Copy into `paper/baseline.md` (or the paper draft):
   - Prefix suite (Llama-3.2-1B, 50 cases): **54% overall**, **memory_recall 20%** (15 cases), persona 66.7%
   - 5-fact toy: LFM 1.2B **1.5/5**, Qwen-0.5B **3.5/5**, Llama-1B **1.5/5**
   - Product QA: Mochi / ramen **fail** even when fact is in SQLite
   - Product: `get_facts_strings(10)` every turn → “I remember…” spam

**Paper work same day:** write §1 Intro + §4.1 Baseline (numbers above). You are already writing.

### Day 2 (2–3 h) — Define metrics (these are your paper metrics)

Measure **four** numbers only:

| Metric | How |
|--------|-----|
| **Recall@ask** | On explicit recall Qs, gold fact appears in reply (exact or fuzzy 0.82) |
| **Spam@chitchat** | On “hey” / “how are you” / “lol”, count replies that mention a stored fact **or** say “I remember” |
| **Injected tokens** | Chars/tokens in the memory prefix (dump vs `[KNOW:]`) |
| **Anchor hit** | Did Pass 1 pick the right node? (independent of the LLM) |

Ablations (same harness, flip flags):

| ID | Condition |
|----|-----------|
| D | no memory |
| F | always-inject facts (today’s product) |
| V | vector only, cutoff 0.62, no hops |
| G | vector + 1-hop (the claim) |
| G+ | G + identity prefill for name/pet/likes asks |

**Paper work:** write §3.4 Evaluation protocol. No new code yet.

### Day 3–4 (4–5 h) — Schema + dual-write (Change 2, smallest)

Add SQLite tables (same DB, no Kùzu):

```sql
CREATE TABLE IF NOT EXISTS nodes (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT NOT NULL,
  summary TEXT,
  attrs TEXT,
  source TEXT DEFAULT 'chat',
  updated_at INTEGER,
  embedding BLOB
);
CREATE TABLE IF NOT EXISTS edges (
  src INTEGER NOT NULL,
  rel TEXT NOT NULL,
  dst INTEGER NOT NULL,
  valid INTEGER DEFAULT 1
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_nodes_kind_name ON nodes(kind, name);
```

Kinds for the 2-week paper: `person`, `pet`, `place`, `pref` only.  
Rels: `OWNED_BY`, `LIKES`, `LIVES_IN`, `LIVED_IN`, `CORRECTS`.  
Skip `note` / `course` / vision — that is Notes, not this paper.

Extractor: when rules fire “User has a cat named Mochi”, **also** `INSERT OR IGNORE` node + `OWNED_BY` → user. Keep writing old `facts` so nothing else breaks.

**Runnable check:** after one chat turn, `SELECT * FROM nodes` shows Mochi.

**Paper work:** draw Figure 1 (ingest → node/edge). Write §3.2 AKF.

### Day 5 (2 h) — Week 1 stop

- Screenshot / log of nodes table
- Baseline table in the draft
- Do **not** start Flutter. Do **not** start ClassSync.

---

## Week 2 — Two-pass retrieve + the experiment that is the paper

### Day 6–7 (4–5 h) — Retrieval change (the actual contribution)

In `gather_memories` / search:

1. Embed the query (already exists).
2. Cosine vs **node** embeddings (fallback: embed `summary` on the fly if blob null).
3. If max cosine **< 0.62** and prompt is not a recall ask → inject **nothing**.
4. Else take top-1 node + 1-hop neighbors, cap **3 nodes**.
5. Prefix: `[KNOW: pet Mochi — your cat]` not a comma-list of a life.

Keep `build_recall_prefill` and extend: name / pet / likes / place (fixes Mochi + ramen even if the 1.2B is poetic).

**Runnable check (write this as `tests` or a 20-line Rust/Python assert):**

```
store: name=Pratay, pet=Mochi, pref=ramen
"hey"                 → inject empty, reply has no Mochi/ramen/"I remember"
"what's my cat's name?" → inject only Mochi, reply contains Mochi
"what do I love?"     → inject ramen
```

If this fails, the paper has no result. Fix this before anything else.

### Day 8 (3 h) — Run the ablation

Same 50-case prefix set **and** a 20-prompt chitchat set you write by hand (hey, thanks, lol, I’m tired, what’s up, …).

Fill:

| Condition | Recall@ask | Spam@chitchat | Avg inject tokens |
|-----------|------------|---------------|-------------------|
| D no memory | | | 0 |
| F always-inject (old) | | high | ~200 |
| V vector 0.62 | | | |
| G + 1-hop | | **target: ~0** | ~40 |

Also re-run the **5-fact toy** on LFM 1.2B vs Llama 1B vs Qwen 0.5B under **G**. That is Table 2 (model × memory).

**Paper work:** §5 Results — paste the table. Discuss: LFM may still ignore KNOW (you already saw 1.5/5). Then the claim is **systems**: less spam + better *anchor*, and prefill for asked slots.

### Day 9 (2 h) — Failure analysis (labs love this)

Take 10 fails. Tag: extractor miss / wrong anchor / LLM ignore / tense (`LIVED_IN`).  
You already have Mochi, ramen, Tokyo-as-current, “explain like I’m 5”.

**Paper work:** §5.3 Error taxonomy. This is stronger than another 0.5% on a leaderboard.

### Day 10 (2 h) — Write the rest + freeze

- Abstract, limitations (CPU 1.2B, no Kùzu, English rules, no user study)
- One figure: two-pass (vector → hop → KNOW)
- README in the repo: how to reproduce Table 1

**Ship for the 2 weeks:** draft PDF + one flag `AURA_MEMORY=graph|legacy` + the three asserts.

---

## What you explicitly do **not** do in these 2 weeks

- ClassSync / Notes / quiz  
- Kùzu, 1024-d, CLIP  
- Flutter UI polish, Play Store  
- Voice, camera, bandit, SFT  
- Nine repos  

Those are later chapters or “future work.”

---

# B. Paper outline + numbers you already have

**Working title (honest):**  
*Query-Anchored Personal Graphs for On-Device Companions: When Not to Retrieve*

**Venue shape:** workshop / Mitacs / internship report / short conference (6–8 pages). Not NeurIPS. That’s fine.

You can type §1–§2–§4 **this week** before Week 2 code lands. Use **measured** numbers. Do **not** copy the old thesis abstract that claims 89% vs 62% and 2.3× engagement unless you re-run and confirm — those look like **targets**, not logs.

## Numbers that are real (cite these)

### Memory (the paper’s core)

| Source | Setup | Number | Use as |
|--------|--------|--------|--------|
| `personal_memory_report.md` | Llama-3.2-1B, prefix `[MEMORY:]`, 50 cases | **54%** overall; **20%** on memory_recall (3/15); 69% general; 66.7% persona | Baseline product-style injection |
| Same file | Note | Previous **83.4%** was **appendage** arch; marked **obsolete** | Related-work caution: metric/arch mismatch |
| `raw_memory_recall_comparison.md` | 5 facts → 5 asks, injection ON | Qwen-0.5B **3.5/5**; Llama-1B **1.5/5**; LFM-1.2B **1.5/5**; Qwen3-0.6B **0/5** | Model × memory table |
| `FEATURE_STATUS.md` | Internal 1.2B vs Aria-450M | Persona 5/10 vs 1/10; Recall 7/10 vs 7/10; Quality 5/10 | Product score (different rubric — say so) |
| QA logs | Mochi, ramen | **Fail** despite row in `facts` | Motivating example |
| Code | `get_facts_strings(10)` every turn | Always-on dump | Problem statement |
| Code | hybrid cosine + BM25, cutoff ~0.45 | Too leaky | Why firewall 0.62 |

### Latency / systems (one paragraph + appendix)

| Source | Number |
|--------|--------|
| `BENCHMARK_REPORT.md` (230M CPU) | TTFT 34–55 ms; **72.3 tok/s** agg; KV hit 39 ms vs miss 1041 ms (**26.6×**) |
| `FEATURE_STATUS.md` (1.2B CPU) | **~0.7 tok/s**, **~8 GB**, **~18.8 s**/reply, warmup **17 s** |
| Identity cache microbench | HashMap ~0.25 µs vs SQLite ~6.8 µs (~28×) — optional footnote |

### Persona / models (related work table, not the claim)

| Model | Persona | Recall (injected) | Notes |
|-------|---------|-------------------|--------|
| LFM2.5-1.2B | Best voice, 0 “as an AI” | Ignores MEMORY (poetic) | Ship persona |
| LFM2.5-230M | Broken | Literal dump | Too small |
| Qwen2.5-0.5B | Leaks “as an AI” (9) | **Best** of small set | Recall vs persona |
| Llama-3.2-1B | Strong | Uses facts more naturally | Best balance in 30-case writeup |
| Aria-450M | Identity collapse | — | Do not ship |

### Do **not** write as fact until re-measured

- “89% hybrid vs 62% vector-only” (`thesis_outline.md` abstract)  
- “Bandit 2.3× engagement”  
- “SFT persona 60% → 91%”  

If you want those claims, they become **Week 3+ experiments**, not this paper’s spine.

---

## Outline (start writing now)

### Title + authors + abstract (write last, draft first)

Template (fill numbers after Week 2):

> Always-inject RAG makes small companions recite the user’s life. We replace a flat SQLite fact dump with a typed personal graph (AKF) and a two-pass retrieve: dense anchor, then one hop, then a `[KNOW:]` line only if cosine ≥ 0.62. On-device (no cloud). Baseline prefix injection on Llama-3.2-1B scores **54%** overall and **20%** on recall items; a 5-fact probe scores **1.5/5** on LFM2.5-1.2B. We report Recall@ask, Spam@chitchat, and injected tokens for dump vs graph. Contribution is **when not to retrieve**, not a new frontier model.

### 1. Introduction (start today)

- Companions must remember **and** shut up.  
- Cloud (Replika / Character / Pi) vs on-device privacy.  
- Failure story: fact in DB, “what’s my cat’s name?” fails; “hey” dumps ramen.  
- Claim: typed graph + firewall > always-inject.  
- Contributions (3 bullets): AKF, two-pass + 0.62, eval (Recall@ask vs Spam@chitchat).  
- Not claiming: new LLM, Kùzu, screen OCR, bandit.

### 2. Related work (start today — no code)

- RAG (Lewis), MemGPT, GraphRAG / HippoRAG / Archipelago-style OKF.  
- **Position:** Archipelago = curriculum OKF + Kùzu + 1024-d. We take **shape only**; ontology is person/pet/pref; store is SQLite; embedder is 384-d already in-product.  
- On-device SLMs: LFM, Llama-3.2-1B, Qwen-0.5B.  
- Companion memory: usually chat history or cloud.

### 3. Method (write Day 3–7)

- 3.1 Product context (one figure: Flutter–FRB–Rust) — ½ page.  
- 3.2 AKF node/edge (JSON example: Mochi).  
- 3.3 Active ingest (rules → MERGE).  
- 3.4 Two-pass + firewall + `[KNOW:]` + optional slot prefill.  
- 3.5 What we refuse (always `get_facts_strings(10)`).

### 4. Experimental setup (write Day 2)

- Hardware: your laptop (name CPU).  
- Models: LFM 1.2B, Llama 1B, Qwen 0.5B, Q4_K_M.  
- Datasets: 50-case prefix set; 5-fact toy; 20 chitchat; optional 1000-case later.  
- Metrics: the four above.  
- Conditions: D / F / V / G.

### 5. Results (Week 2)

- Table 1 ablations.  
- Table 2 models × G vs F.  
- Figure: spam vs recall tradeoff.  
- 5.3 Errors (Mochi, ramen, Tokyo, idiom-as-age).  
- Honest: if LFM still ignores KNOW, say **retrieval succeeded, generation failed** — that’s a result.

### 6. Discussion

- Product vs bench: 7/10 internal recall ≠ 20% suite — **different tests**; you compare **same harness** before/after, not 7/10 vs 89%.  
- Why 0.62 not 0.75 (companion queries are short).  
- SQLite vs Kùzu (n is hundreds).

### 7. Limitations + future

- English rules, CPU, no user study, Notes/`UNLOCKS` out of scope, SFT later.

### 8. Conclusion (5 sentences)

### Appendix

- Latency table (230M 72 tok/s vs 1.2B 0.7) — systems context, not the claim.  
- Reproduce commands.

---

## How “product numbers vs research numbers” works (your earlier question)

| Kind | Example | Role |
|------|---------|------|
| **Research / harness** | 20% recall on 15 prefix items; 1.5/5 toy | What you can reproduce in a paper |
| **Product / QA** | Mochi fail, “I remember” on idle | Motivation + qualitative |
| **Internal rubric** | 7/10 recall, 5/10 persona | Say “different rubric”; don’t mix into Table 1 |
| **Draft targets** | 89%, 2.3× | Only if you run that ablation |

**Good paper:** same 50 + 20 prompts, F vs G.  
**Bad paper:** “we improved 20% → 89%” by switching dataset.

---

## After these 2 weeks (not now)

- Chapter 2 = latency (you already have 26.6× KV).  
- Chapter 3 = Notes `REQUIRES`/`UNLOCKS`.  
- Internship packet = **this paper + AURA demo video**, not nine GitHubs.

Nine hand-built minis prove energy. **One measured graph-RAG result plus a running companion** proves you can do lab work.

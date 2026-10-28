# Detailed Plan: Change 1 + Change 2

**Ponytail:** Reuse existing SQLite. Add one graph table. No new DB. No Kùzu yet. Make it dynamic with active ingestion + query-anchored retrieval. ClassSync becomes personal notes.

**Goal:** Make memory a **human-like graph RAG** — active ingestion + retrieval that learns dynamically, not static SQL spam. Replace ClassSync peer stuff with my notes.

---

## Core Vision (One Memory Path)

Today memory is flat SQL facts + always-inject.

**New reality:**
- Graph: nodes + edges (SQLite adjacency first)
- Ontology: AURA-friendly kinds (person, pet, place, pref, note, course)
- Retrieval: vector anchor + limited hop (1–2 hops)
- Active ingestion: extract AKF on every turn
- Retrieval: only inject when cosine >= 0.62 or explicit ask
- Never dump facts
- Human-like: silent learning, mention only when asked

ClassSync features to keep: my courses, notes, quiz, summary, doubts.

---

## Session 0 — Honesty & Rename (30 min)

**What to do:**
1. Delete share-code / join-code logic from `class_card.dart` and `menu_sheet.dart`.
2. Rename “ClassSync” → “Notes” everywhere in UI strings.
3. Remove roster, attendance, stream, leaderboard tabs (keep only my courses + notes).
4. Add “Personal Notes” world (same as Class mode but no peers).

**Files:**
- `class_card.dart` — delete `_classCode`, `_shareCode`
- `class_screen.dart` / `menu_sheet.dart` — rename to Notes
- `class_detail_page.dart` — drop Students / Attendance / Stream tabs

**Verification:** “ClassSync” string gone. Notes tab exists with CRUD.

---

## Session 1 — Nodes + Edges + Dual-Write Extractor (1.5 hours)

**What to do:**
1. Add `nodes` table (SQLite) and `edges` table (adjacency list).
2. Change extractor (`worker_utils/rules/*`) to output AKF JSON instead of only `facts.fact`.
3. Dual-write: still fill old `facts` (Notebook UI safe) + new `nodes` / `edges`.
4. Add `kind`, `name`, `summary`, `attrs`, `source`, `updated_at` to nodes.
5. Add edges table for directed relations.

**Schema (run once on init):**
```sql
CREATE TABLE nodes (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT NOT NULL,
  summary TEXT,
  attrs TEXT, -- JSON
  source TEXT DEFAULT 'chat',
  updated_at INTEGER,
  embedding BLOB
);

CREATE TABLE edges (
  src INTEGER NOT NULL,
  rel TEXT NOT NULL,
  dst INTEGER NOT NULL,
  valid INTEGER DEFAULT 1
);
```

**Files to change:**
- `worker_utils/rules/mod.rs` — output AKF nodes + edges
- `memory/store/facts.rs` → new `nodes.rs` + `edges.rs`
- `memory/store/core.rs` — schema + dual-write
- `memory/store/search.rs` — search nodes, not facts

**Ponytail:** Keep `facts` table for Notebook UI. Graph is extra.

**Verification:** One test turn extracts “Mochi” as pet node + edge `OWNED_BY user`.

---

## Session 2 — Two-Pass Graph RAG + Firewall + [KNOW:] (1.5 hours)

**What to do:**
1. Change retrieval: vector search on `nodes.embedding`, not flat `facts`.
2. Raise cosine firewall to **0.62** (today ~0.45).
3. 1-hop traversal on `edges` (up to 2 hops).
4. Inject only if matches (or explicit identity ask).
5. Prefix: `[KNOW: pet Mochi — your cat]` not `[MEMORY: …]`.
6. System prompt rule: never say “I remember”; never list unused facts.

**Files:**
- `api/chat/turn/memory.rs` — two-pass
- `api/chat/turn/prefix.rs` — `[KNOW:]` format
- `memory/store/search.rs` — cosine + firewall + hop
- `memory/store/retrieval.rs` — `get_facts_strings` → `get_nodes_for_query`

**Ponytail:** SQLite hop is ceiling. Upgrade to Kùzu when > few thousand edges.

**Verification:** Prompt “what's my cat's name?” injects only Mochi node. Prompt “hey” injects nothing.

---

## Session 3 — Personal Note Taker (1 hour)

**What to do:**
1. Add `kind = 'note'` to nodes.
2. Course = `kind = 'course'`.
3. Notes tab reads `kind = 'note'` for that course.
4. Quiz / summary / doubts read only that course's notes.
5. File ingest already exists — route to that course's notes.

**Files:**
- `class_detail_page.dart` — replace Students tab with Notes tab
- `notebook_page.dart` — add course filter
- `file_sense_service.dart` — add course context

**Verification:** Create a course, add a note, quiz from that note only. No peer data.

---

## Session 4 — Polish & Store Cut (1 hour)

**What to do:**
1. Add “Wipe all memory” button (new table `memory_wipe_log`).
2. Add camera / mic settings toggle.
3. Add first-run “what we store” screen (Privacy policy ready).
4. Update README with store listing text.

**Verification:** Wipe works. Camera off by default. Notes survive restart.

---

## Overall Architecture (one picture)

```
User Prompt
  ↓
Vector Search (384-d) + Firewall 0.62
  ↓
Anchor Node (e.g. pet Mochi)
  ↓
1–2 Hop Traversal on edges (HAS, LIKES, ABOUT, REQUIRES)
  ↓
[KNOW: pet Mochi — your cat]
  ↓
Local LLM (1.2B) → Reply
```

No static SQL dump. No “I remember” spam. Dynamic, human-like.

---

## Rollback

If graph misbehave:
- Flip `get_nodes_for_query` back to `get_facts_strings`
- Nodes table can be dropped (dual-write still works)

---

## Estimated effort (lazy)

- Session 0: 30 min
- Session 1: 1.5 h
- Session 2: 1.5 h
- Session 3: 1 h
- Session 4: 1 h

**Total: ~6 hours.** No new dependencies. All SQLite.

---

## Next step

Run Session 0–1 first (honesty + basic graph). Then tell me **"do Session 2"** (two-pass RAG) and we'll continue.

This is the detailed plan. The system will learn dynamically through active ingestion + retrieval instead of static SQL spam. ClassSync becomes personal notes.

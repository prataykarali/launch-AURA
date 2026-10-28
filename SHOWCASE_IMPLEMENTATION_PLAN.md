# AURA Implementation Plan — Legacy Launch

**Goal:** Ship the smallest real companion that can live on a laptop store **and** Play Store. Start the AURA lineage. Research numbers already exist. This plan is product, not more benches.

**Ponytail:** Delete and reuse before inventing. No new cloud. No fake multi-user. No new graph DB until SQLite hops hurt. One memory path, one note path, two store skins.

---

## What “AURA legacy” means

AURA is a **local digital companion** (ARIA). The first public cut must do four things well:

1. Stay on the machine (bar on laptop, overlay or in-app pill on phone).
2. Talk locally (small LLM, streaming).
3. Remember **quietly** (graph + vector, not “I remember x, y, z” after every chat).
4. Take **personal** notes for school/work (not a fake classroom network).

Everything else is later.

---

# Part A — MVP lists (what ships)

Two storefronts, **one engine**. Same Rust memory + chat. Different skins and permissions.

## A1. Shared core (both stores)

**Ship**

| Feature | Why it is MVP |
|---------|----------------|
| Local chat + ARIA persona (1–3 sentences) | The product |
| Streaming tokens + cancel | Feels alive |
| Quiet memory (query-anchored, no dump) | Differentiator |
| Notebook: see / pin / delete facts & notes | Trust + store reviewers |
| Personal note taker (ex-ClassSync) | Second world, no peers |
| Push-to-talk voice **or** typed chat (voice optional if flaky) | Companion body |
| Settings: camera off, mic off, online-translate off, wipe memory | Play / privacy |
| First-run permission + “what we store” screen | Store policy |
| Offline by default | The claim |

**Do not ship (both)**

- Peer / class codes / roster / attendance of others / leaderboard
- “Remind me in 2 min” (LLM lies; no timer)
- “I can see your screen”
- Always-on camera / wake-word
- 450M Aria as the face (identity break)
- Web search, calendar, smart home, multi-persona
- “I remember …” spam, full fact dumps in every reply
- Proactive that recites birthday / name unprompted

---

## A2. Laptop store MVP (Linux first → later Snap / Flathub / .deb)

**This is v1 of the legacy.** Linux is already the real product.

### Must work

| Item | Bar |
|------|-----|
| AURA Bar pill + tray + independent lifecycle | **Required** |
| Home chat | Required |
| Notebook (facts / notes / wipe) | Required |
| Personal note taker world (rename ClassSync) | Required |
| LFM2.5-1.2B local | Required |
| Quiet memory + name recall that works | Required |
| Camera **opt-in**, off by default | Optional extra, not store-blocking |
| Local Piper TTS **if** `sample_rate` metadata is patched; else typed-only is OK | Voice is bonus |
| Push-to-talk STT if Whisper/sherpa actually returns text | Bonus |
| One-command / `.desktop` launcher | Required for store |

### Laptop store packaging (launch checklist)

- App ID, icon 256/512, screenshot set (bar + chat + notes + memory)
- Short desc: *On-device companion that remembers you. No account.*
- Long desc: honest (local model, what memory stores, camera optional)
- `launch_aura.sh` / `.desktop` / Flathub or Snap manifest
- Models downloaded on first run **or** documented extra package (don’t explode the `.deb`)
- Sandbox: mic / camera portals, filesystem only for `~/.local/share/aura*`
- No Intel-MKL-required path as the only path (reviewers will bounce)

### Laptop cut line

If bar + chat + quiet memory + personal notes run on a clean Ubuntu with one installer, **laptop MVP is done.** Voice/camera are pluses, not gates.

---

## A3. Play Store MVP (Android)

**Smaller skin. Same brain.** Overlay is the landmine — do not let it block launch.

### Must work

| Item | Bar |
|------|-----|
| In-app chat (main activity) | **Required** |
| ARIA + local or on-device-small model (230M / 0.5–1B Q4, **not** broken 450M identity) | Required |
| Quiet memory + wipe | Required |
| Personal note taker (my classes / my notes only) | Required |
| Settings + privacy screen | Required |
| Typed input that always works | Required |
| Platform STT **in-app** (not overlay) if permission granted | Bonus |
| Platform TTS if not choppy; else text-only | Bonus |

### Must **not** ship on v1 Play

| Item | Why |
|------|-----|
| Broken overlay (full-width tap steal, no keyboard, wrong FGS type) | 1-star + policy |
| Overlay as the **only** UI | Reviewers / OEM kill |
| Background mic without a visible FGS + mic type | Play policy Android 14+ |
| Always-on camera | Policy + battery + trust |
| Fake “join class with code” | Deceptive |
| 8 GB RAM 1.2B as the only model | ANRs / Play vitals |

### Play overlay rule (ponytail)

v1: **in-app companion pill only.** Overlay is v1.1 after: microphone FGS type, `FLAG_NOT_TOUCH_MODAL`, compact width, keyboard focus when typing, OEM battery copy.

### Play Store listing checklist

- Privacy policy URL (what is stored on device, no account, optional online TTS/translate)
- Data safety: no sale, no account, mic/camera optional, files = user notes
- Target / compile SDK current; 64-bit; 16 KB page if required
- Foreground service types declared **only** for what you use
- Content rating, screenshots (phone + if tablet), short/long desc matching **actual** features
- Prominent disclosure before mic / camera
- “Wipe all memory” in settings (store trust)

### Play cut line

If a reviewer can install, type to ARIA, get a short local reply, see a saved note, wipe memory, and never get a stuck overlay — **Play MVP is done.**

---

## A4. Store split (one picture)

```
                    ┌─────────────────────────┐
                    │  Rust engine (shared)   │
                    │  chat · quiet memory    │
                    │  notes ingest           │
                    └────────────┬────────────┘
           ┌─────────────────────┴─────────────────────┐
           ▼                                           ▼
   Laptop store                              Play Store
   Bar + tray + 1.2B                         In-app chat + small model
   Optional cam / voice                      Typed first, voice bonus
   Personal notes                            Personal notes
   No ClassSync peers                        No overlay-as-product
```

---

# Part B — Change 1: ClassSync peer-peer → personal note taker

**Today:** Class mode pretends to be a classroom network (join codes, share list, students roster, attendance, classmate leaderboard). None of that is real multi-user. It is dishonest UX and it will fail store review if we imply sync.

**Now:** One student. One device. Notes for *their* classes.

### Kill (peer / LMS theater)

- Class join / share **code**
- “Share Class List” as if others join
- Students roster as other people
- Attendance of a class
- Classmate leaderboard
- Stream-as-social-feed
- Menu label **ClassSync** / “About ClassSync”

### Keep (already useful)

- List of **my** courses (CRUD, local SQLite)
- Lessons / resources as **my files**
- AI quiz from *my* notes
- My doubt queue (questions I typed)
- Lesson summariser
- Subject overlay chat (ask about this course)

### Add (the replacement)

Rename world: **Notes** (or “Study”). Each course is a **notebook**, not a classroom.

| Surface | Behavior |
|---------|----------|
| Course card | Name, subject, teacher (optional). No join code. |
| **Notes tab** (replaces Students) | Timestamped personal notes. Type, paste, or ingest a file (`FileSense` already exists). |
| Capture | “Add note” / voice-to-note (reuses STT if up). Saved to that course + memory graph as `Note` nodes. |
| Quiz / doubts / summary | Grounded on **that course’s notes only**, not global fact dump. |
| Overview | My progress on *my* notes (topics I added), not XP theater if it implies peers. |

### Files to touch (shortest path)

- `class_card.dart` — delete `_classCode` / `_shareCode`
- `menu_sheet.dart` / `class_screen.dart` — rename ClassSync, share → export **my** notes as text
- `class_detail_page.dart` — drop Students / Attendance / Stream tabs; add Notes tab
- Reuse `notebook_page` note CRUD + `file_sense_service` instead of a new backend
- Copy: “Your notes stay on this device.”

**ponytail:** Do not build sync. Export `.md` / JSONL is enough if someone wants backup.

---

# Part C — Change 2: Cleansify memory (Archipelago ideas, AURA shape)

## The problem

Today every turn:

1. `get_facts_strings(10)` always injects a static SQL dump.
2. Prefix becomes `[MEMORY: your name is X, you like Y, …]`.
3. 1.2B recites: “I remember X, Y…” even when nobody asked.
4. Facts are flat strings. No type, no edges, no “this corrects that.”
5. Vision rows sit in the same `facts` table and leak into identity.

Archipelago is right about **structure + two-pass retrieval**. It is wrong to copy **curriculum OKF** (difficulty, UNLOCKS, textbooks) onto a companion.

AURA is not a textbook graph. AURA is a **person graph**.

## AURA Knowledge Format (AKF) — OKF adapted

One JSON node. Eight keys, but **companion** keys, not pedagogy.

```json
{
  "name": "Mochi",
  "kind": "pet",
  "summary": "User's cat.",
  "attrs": { "species": "cat" },
  "related": ["ramen"],
  "edges_out": [
    { "rel": "OWNED_BY", "to": "user" },
    { "rel": "ALSO_CALLED", "to": "the cat" }
  ],
  "source": "chat",
  "updated_at": 0
}
```

**Kinds:** `person` (user + people they name) · `pet` · `place` · `pref` · `goal` · `event` · `note` · `course` · `vision` (separate, never identity).

**Rels (directed, tiny set):**

| Rel | Meaning | Archipelago analog |
|-----|---------|-------------------|
| `ABOUT` | note/event → entity | related_to |
| `HAS` / `OWNED_BY` | user → pet, user → thing | — |
| `LIKES` / `DISLIKES` | user → pref | — |
| `LIVES_IN` / `LIVED_IN` | user → place (tense = edge, not a blob) | — |
| `CORRECTS` | new node supersedes old | MERGE + invalidate |
| `RELATED` | soft neighbor | related_to |
| `REQUIRES` / `UNLOCKS` | **only inside Notes/courses** | OKF pedagogy |

`REQUIRES`/`UNLOCKS` stay in the **note taker** (lecture concepts). They do **not** wrap “user likes ramen.”

Canonical MERGE: same `kind` + normalized `name` → one node. “Mochi” from two chats is one pet. “I used to live in Tokyo” is `LIVED_IN`, not a current `LIVES_IN`.

## Two layers (same as Archipelago, cheaper)

### 1. Vector — entry anchor (you already have this)

Keep BGE / Snowflake **384-d** ONNX. Do not jump to 1024-d / bge-m3 for MVP.

- Embed `summary` + `name` of each node (and note chunks).
- Pass 1: cosine against **nodes**, not a raw dump of all facts.
- **Firewall:** raise cutoff. Today hybrid is ~0.45 (too leaky). Launch default **0.62**; kill-switch (inject nothing except silent identity) if top score `< 0.62`.
- Identity exception: `kind=person, name=user` may attach **one line** (`your name is X`) only when the prompt is a name/identity ask — use existing `build_recall_prefill`, expand to pet/pref asks.

### 2. Graph — topology (do **not** add Kùzu yet)

**ponytail:** personal graph is tens–hundreds of nodes. SQLite adjacency is enough. Ceiling: recursive k-hop gets ugly past a few thousand edges → then Kùzu.

```
nodes(id, name, kind, summary, attrs_json, source, updated_at, embedding)
edges(src, rel, dst, valid)          -- valid=0 when CORRECTS fires
```

Pass 2 after an anchor:

- 1-hop out / in on `HAS`, `LIKES`, `OWNED_BY`, `ABOUT`, `RELATED`
- For a **course note** question: also 1-hop `REQUIRES` / `UNLOCKS`
- Cap: **3 nodes + 4 edges** in the prompt. Never 10 raw SQL strings.

## How they work together (AURA two-pass)

```
User: "what's my cat's name?"
  Pass 1  embed query → anchor node kind=pet name=Mochi  (cosine ≥ 0.62)
  Pass 2  1-hop OWNED_BY → user
  Prompt  [KNOW: pet Mochi — your cat]
  Reply   "Mochi."     — not "I remember you have a cat named Mochi and you love ramen and..."
```

```
User: "hey"
  Pass 1  top cosine < 0.62
  Pass 2  skipped
  Prompt  (no memory block)
  Reply   short greeting — no fact recital
```

```
User: "what should I study next?"  (inside Notes / a course)
  Pass 1  anchor = last course concept
  Pass 2  UNLOCKS / REQUIRES 1-hop
  Prompt  [KNOW: you finished LoRA; unlocks QLoRA]
```

## Stop the spam (prompt + retrieval)

Change `gather_memories` / `build_memory_prefix`:

1. **Do not** call `get_facts_strings(10)` on every turn.
2. Inject memory **only if** (identity-ask) OR (top cosine ≥ firewall).
3. Prefix format: `[KNOW: …]` one line per **anchor**, not a comma list of a life story.
4. System rule (already drafted in ENGINEERING_ISSUES): never say “I remember”; never list unused facts; if unused, stay silent on them.
5. Consecutive-memory guard stays (max 2 turns with a KNOW block).
6. Vision nodes never enter Pass 1 unless the turn is classified vision.

## Extractor change

Rules engine already has identity / family / pets / prefs / location / goals / events.

- Write **nodes + edges**, not only `facts.fact` text.
- Multi-fact sentence → multiple nodes (today it keeps the first).
- “used to live in Tokyo” → `LIVED_IN`, not current place.
- “actually it’s Mochi not Mochi-chan” → `CORRECTS`, old edge `valid=0`.
- Keep JSONL mirror: one AKF object per line (this **is** the Open Knowledge Format file).

Dual-write for one release: still fill old `facts` so Notebook UI does not die; read path uses nodes. Then drop the dump path.

## What we refuse from Archipelago

| Archipelago | AURA |
|-------------|------|
| 8 pedagogical keys (difficulty, textbooks) | companion kinds |
| Kùzu required | SQLite first |
| 1024-d arctic/bge-m3 | existing 384-d |
| 0.75 hard OOD kill for **curriculum** | 0.62 + identity exception |
| Gemini synthesizer | local 1.2B / phone-small |
| Page citations | chat turn id + note id |

Same **shape**. Different **ontology**. No new cloud model.

## Files (memory)

- `api/chat/turn/memory.rs` — stop always-dump; two-pass
- `api/chat/turn/prefix.rs` — `[KNOW:]` not life-story `[MEMORY:]`
- `memory/store/facts.rs` + new `nodes.rs` / `edges.rs`
- `memory/store/search.rs` — search **nodes**; firewall 0.62
- `worker_utils/rules/*` — emit AKF + edges
- `config` persona: anti-recital rules
- Notebook UI: show graph nodes, not only raw fact strings

**Runnable check:** one assert test — prompt `"hey"` injects **zero** pref facts; `"what's my cat's name?"` injects only the pet node. Fails if ramen/name dump returns.

---

# Part D — Phased work (lazy order)

### Phase 0 — Honesty (half day)

- Rename ClassSync → Notes in UI copy.
- Hide share-code / students / attendance / leaderboard from the default tab set (can leave files, stop routing).
- Turn **off** proactive fact recital (rules already written).
- Camera / overlay / reminders: hide or label experimental.

### Phase 1 — Personal note taker (1–2 days)

- Notes tab + file ingest per course.
- Quiz / summary / doubts read **course notes only**.
- Export my notes. No peers.

### Phase 2 — Quiet memory / AKF (2–4 days)

- `nodes` + `edges` tables; dual-write from extractor.
- Two-pass retrieve + 0.62 firewall + `[KNOW:]`.
- Expand `build_recall_prefill` to pet / likes / place (fixes Mochi + ramen).
- `"hey"` injects nothing.
- Anti-“I remember” in system prompt.

### Phase 3 — Laptop store MVP (2–3 days)

- Root README + `launch_demo.sh` + `.desktop`.
- Piper `sample_rate` metadata inject (script already in `scripts/inject_onnx_metadata.py`).
- First-run model path without MKL-only.
- Screenshots + short/long listing text.
- Cut: bar + chat + quiet memory + notes.

### Phase 4 — Play Store MVP (3–5 days)

- Phone-small model path (not Aria-450M identity).
- In-app pill only; overlay behind a debug flag.
- Privacy policy + data safety + wipe.
- Mic FGS only if in-app STT ships.
- Play screenshots of **chat + notes + settings**, not broken overlay.

### Phase 5 — Overlay / voice / camera as v1.1

- Fix Android overlay (FGS mic, width, focus).
- Linux sherpa path + no zombie Whisper.
- Camera opt-in events as `kind=vision` nodes.

### Phase 6 — Showcase wrap (paper / internships)

- README, one installer, one memory figure (vector → 1-hop → KNOW).
- Point at existing Mitacs numbers. Do not rerun the world.

---

# Part E — Definition of done

**Laptop store:** stranger installs, opens bar, says their name and cat, later asks the cat’s name, gets **one** correct word, says “hey” and does **not** get a biography. Creates a course, adds a note, quizzes from that note.

**Play Store:** same memory + notes loop with **typing**, no overlay crash, wipe works, Play Data safety matches the app.

**Legacy started when:** those two loops exist on two storefronts, ClassSync is gone, memory is a small person-graph, and we never again ship “I remember x, y, z” as the default personality.

---

## Effort (honest)

| Phase | Time |
|-------|------|
| 0 Honesty | 0.5 d |
| 1 Notes | 1–2 d |
| 2 Quiet memory | 2–4 d |
| 3 Laptop MVP | 2–3 d |
| 4 Play MVP | 3–5 d |
| 5 Overlay/voice | later |
| 6 Paper wrap | 1 d |

No new deps in 0–4. Kùzu / 1024-d / CLIP / reminders stay off the MVP.

## Rollback

Graph dual-write: if nodes misbehave, flip read path back to `facts` (one flag). UI rename is copy-only.

---

This file is the implementation plan. Lists above **are** the Play Store and laptop MVPs. Change 1 and change 2 are the first two build slices after honesty.

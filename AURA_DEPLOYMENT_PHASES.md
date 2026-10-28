# AURA Legacy Deployment Phases

**Goal**: Ship the total shippable product in clear, incremental phases for both **Play Store (Android)** and **laptop store (Linux)**.

**Ponytail**: One engine (Rust memory + chat). Different skins and permissions. Memory cleansify and personal notes are the first two mandatory phases.

---

## Shared Core (ships on both platforms)

| Phase | What ships | Store requirements |
|-------|------------|---------------------|
| **Phase 0: Honesty + Rename** | Local chat + ARIA + quiet memory + wipe + notebook | Privacy policy + data safety |
| **Phase 1: Personal note taker** | My courses + my notes + quiz / summary / doubts (no peers) | Same as Phase 0 |
| **Phase 2: Graph RAG cleansify** | Vector + 1-hop graph + `[KNOW:]` prefix + no spam | Same |

---

## Laptop Store Deployment Phases (Linux first)

**Platform**: Linux desktop (Flathub / Snap / .deb / Microsoft Store later)

### Phase 0: Honesty + Rename (30 min)
**What ships**:
- AURA Bar + tray + independent lifecycle
- Local 1.2B chat
- Quiet memory + wipe
- Notebook (facts + notes)
- Personal Notes world (ex-ClassSync)

**Do not ship**: ClassSync peer stuff

**Laptop store packaging**:
- `.desktop` file
- One-command launcher (`launch_aura.sh`)
- Icons + screenshots (bar + chat + notes)

**Verification**: Stranger opens bar, says their name and cat, gets correct recall, says "hey" gets no biography.

### Phase 1: Personal note taker (1 hour)
**What ships**:
- Notes tab per course
- File ingest + voice/text notes
- Quiz and summary from **that course only**
- Export my notes

**Laptop store packaging**: Same as Phase 0 + additional screenshots of notes.

### Phase 2: Graph RAG cleansify (1.5 hours)
**What ships**:
- Nodes + edges table
- Two-pass retrieval + 0.62 firewall
- `[KNOW:]` prefix
- No fact dumps

**Laptop store packaging**: Same + README with "memory stays local and is recalled only when asked".

**Cut line**: Laptop MVP is done when bar + chat + notes + quiet recall run on a clean Ubuntu with one installer.

### Phase 3: Voice + Camera + Polish (2–3 hours)
**What ships**:
- Piper TTS (after metadata fix)
- Push-to-talk (if reliable)
- Camera opt-in
- First-run "what we store" screen

**Laptop store packaging**: Full `.desktop` + icons + privacy policy.

### Phase 4: Microsoft Store / Snap / Flathub (2 hours)
**What ships**: Same as Phase 3 + store metadata.

---

## Play Store Deployment Phases (Android)

**Platform**: Android (API 24+). Overlay is the landmine — do **not** ship broken overlay in v1.

### Phase 0: Honesty + Rename (30 min)
**What ships**:
- In-app chat
- Local model (small, not Aria-450M identity broken)
- Quiet memory + wipe
- Notebook + personal notes

**Do not ship**: ClassSync peer stuff, broken overlay.

**Play Store requirements**:
- Privacy policy URL
- Data safety: no sale, no account, mic/camera optional
- "Wipe all memory" button

### Phase 1: Personal note taker (1 hour)
**What ships**:
- Notes tab per course
- Quiz / summary / doubts from **that course only**

**Play Store packaging**: Same as Phase 0 + additional screenshots of notes.

### Phase 2: Graph RAG cleansify (1.5 hours)
**What ships**:
- Same two-pass + firewall + `[KNOW:]` as laptop
- No spam

**Play Store requirements**: Same as Phase 0.

### Phase 3: In-app pill + Settings (1 hour)
**What ships**:
- Floating pill in main chat (no overlay)
- Camera / mic toggles
- First-run privacy screen

**Do not ship**: Overlay as product.

**Play Store cut line**: Reviewer installs, types to ARIA, sees notes, wipes memory, never gets stuck overlay.

### Phase 4: Voice + Camera + Polish (2 hours)
**What ships**:
- Platform STT/TTS (in-app only)
- Camera opt-in events
- Full settings

**Play Store packaging**: Full screenshots (chat + notes + settings), privacy policy, "mic and camera optional".

### Phase 5: Full Play Store (3 hours)
**What ships**: All above + store listing text, content rating, data safety.

---

## Summary: Total Shippable Product

| Phase | Laptop Store | Play Store |
|-------|--------------|------------|
| 0 Honesty | Bar + chat + quiet memory + notebook | In-app chat + quiet memory + notebook |
| 1 Notes | My courses + my notes | My courses + my notes |
| 2 Graph RAG | Vector + 1-hop + no spam | Same |
| 3 Voice / Camera | Piper + opt-in camera | In-app STT/TTS + opt-in camera |
| 4 Store polish | Flathub / Snap / .deb | Full Play Store listing |

**One engine**. Two storefronts. Memory stays local and is recalled only when asked.

**Cut line for each store**: The reviewer can install, use the companion, see their notes, and never get a biography dump or broken overlay.

---

## Rollback

Any phase can be rolled back by deleting the nodes/edges table or flipping the retrieval path back to `get_facts_strings`.

---

**Next step**: Run **Phase 0–1** (honesty + notes) for both platforms. Then tell me **"do Phase 2"** (Graph RAG) and we'll continue.

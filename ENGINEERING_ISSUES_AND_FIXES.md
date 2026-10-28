# AURA Engineering Issues — Complete Diagnosis & Fix Guide

Generated: 2026-07-04

---

## Table of Contents

1. [Proactive System Issues](#proactive-system-issues)
2. [Vision / OCR Issues](#vision--ocr-issues)
3. [Memory System Issues](#memory-system-issues)
4. [Multi-Turn Conversation Issues](#multi-turn-conversation-issues)
5. [RL Bandit Issues](#rl-bandit-issues)
6. [Priority Matrix](#priority-matrix)
7. [Step-by-Step Fix Guide](#step-by-step-fix-guide)

---

## Proactive System Issues

### ISSUE P-1: Proactive Prompt Dumps Raw User Facts (ROOT CAUSE OF SPAM)

**Severity:** P0 — Critical
**Files:**
- `AURA-Proj/aura_notebook/lib/services/bar_brain/bar_brain_proactive.dart:110-146`
- `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/retrieval.rs:190-325`

**Problem:**
`_buildProactivePrompt()` calls `auraGetProactiveContext()` which returns:

```
Known facts (about the USER):
- User's name is Pratay
- User's birthday is March 15
- User likes coding
```

The LLM (1.2B model) sees these facts in its context window and naturally regurgitates them: "Hey Pratay! I remember your birthday is coming up!" — because that's the most specific information available.

**Why the current code does this:**
```dart
// bar_brain_proactive.dart:130-138
final context = await auraGetProactiveContext();
if (context.isNotEmpty) {
  final limited = context.length > 200
      ? '${context.substring(0, 200)}...'
      : context;
  buffer.writeln('  memory_context=$limited');
}
```

And in `retrieval.rs:190-229`, `get_proactive_context()` ALWAYS includes the top 4 facts first with a 220-char budget:

```rust
const FACT_BUDGET: usize = 220;    // LARGEST budget — this is the problem
const SUMMARY_BUDGET: usize = 200;
const TURN_BUDGET: usize = 240;
```

**Root Cause Chain:**
```
_triggerProactive()
  → handleProactiveTrigger()
    → _buildProactivePrompt()
      → auraGetProactiveContext()
        → "Known facts (about the USER): - User's name is Pratay..."
          → LLM sees facts + "Reply with a very brief, natural message"
            → 1.2B model → "Hey Pratay! I remember your birthday!"
```

---

### ISSUE P-2: Bandit Trigger Labels Are Fact-Dump Seeds

**Severity:** P0 — Critical
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/core.rs:144-152`

**Problem:**
The 8 seeded trigger labels are context-dependent prompts that invite the LLM to reference stored data:

```rust
let initial_triggers = vec![
    (1, "How's your day going?"),
    (2, "Did you learn anything interesting today?"),
    (3, "I'm here if you need to brainstorm anything."),
    (4, "Ready for our next project?"),
    (5, "I've been thinking about our last conversation..."),  // ← invites memory recall
    (6, "You seem busy today, anything I can help with?"),
    (7, "By the way, I found something you might like."),      // ← invites fabrication
    (8, "Shall we continue where we left off?"),                // ← invites memory recall
];
```

Labels like "I've been thinking about our last conversation..." directly prompt the LLM to dig into the memory_context, which contains user facts.

**Additional problem:** These labels are used as `trigger_label=` in the proactive prompt. The LLM sees:
```
AURA is being proactive. Context:
  trigger_label=I've been thinking about our last conversation...
  memory_context=Known facts (about the USER): - User's name is Pratay...
```

The model combines both and produces: "I've been thinking about our last conversation, Pratay!"

---

### ISSUE P-3: Proactive Prompt Instruction is Too Weak

**Severity:** P1 — High
**File:** `AURA-Proj/aura_notebook/lib/services/bar_brain/bar_brain_proactive.dart:143-145`

**Problem:**
The instruction to the LLM is:
```dart
buffer.writeln(
  'Reply with a very brief, natural English message. '
  'If the context does not justify interrupting the user, reply exactly SILENT (no punctuation).',
);
```

This instruction:
1. Does NOT say "don't recite user facts"
2. Does NOT say "be conversational, not informational"
3. Does NOT say "don't mention stored data"
4. The 1.2B model interprets "natural English message" as "use the context I gave you"

---

### ISSUE P-4: Idle Trigger Has No Activity Context

**Severity:** P1 — High
**File:** `AURA-Proj/aura_notebook/lib/services/proactive_scheduler/trigger_logic.dart:71-87`

**Problem:**
When `idle_checkin` fires after 10 minutes of silence, the proactive prompt has NO idea what the user was doing before going idle. The prompt is:
```
AURA is being proactive. Context:
  trigger_label=idle_checkin
  trigger_type=idle
  memory_context=Known facts (about the USER): - User's name is Pratay...
```

It should say "Looks like you were coding and stepped away" but instead says "Hey Pratay, I remember your birthday."

**Root cause:** The vision context (`_lastScreenText`, activity classification) is never passed to the proactive prompt builder.

---

### ISSUE P-5: Idle Trigger Fires Too Frequently

**Severity:** P1 — High
**File:** `AURA-Proj/aura_notebook/lib/services/proactive_scheduler/service.dart:71`

**Problem:**
```dart
static const Duration idleThreshold = Duration(minutes: 10);
```

Combined with a 20-minute cooldown, if a user is idle for 30+ minutes, they get pinged every 20 minutes indefinitely. There is no exponential backoff.

The `_lastIdleTrigger` guard only prevents back-to-back idle pings within the cooldown window, but after the cooldown expires, if the user is still idle, it fires again immediately.

---

### ISSUE P-6: Clock Triggers Use Clean Templates but Bandit Triggers Don't

**Severity:** P2 — Medium
**File:** `AURA-Proj/aura_notebook/lib/services/bar_brain/bar_brain_proactive.dart:96-108`

**Problem:**
Clock-based triggers (morning/afternoon/evening) get clean templates WITHOUT conversation context:
```dart
if (type == 'clock' || label == 'morning_greeting' ...) {
  buffer.writeln('Say a brief, warm $greeting to the user.');
  buffer.writeln('Reply in 1-2 sentences. Be natural and friendly.');
  buffer.writeln('Do NOT mention any previous conversations or context.');
  return buffer.toString().trim();
}
```

But ALL other triggers (including idle_checkin, bandit triggers) go through the fact-dumping path. The clock path proves the architecture CAN work cleanly — the fix is to apply the same pattern to all conversational triggers.

---

## Vision / OCR Issues

### ISSUE V-1: Triple Tesseract Invocation Per Frame

**Severity:** P2 — Medium
**Files:**
- `AURA-Proj/aura_notebook/lib/services/vision_service/analysis.dart` — `_extractScreenText()`
- `AURA-Proj/aura_notebook/lib/services/vision_service/capture.dart` — `_runScreenOcr()`
- `AURA-Proj/aura_notebook/lib/services/vision_service/ocr_stuck.dart` — `_ocrFrame()`

**Problem:**
Each frame capture can spawn up to 3 separate `tesseract` processes. Each:
1. Writes a temp JPEG/PNG to `/tmp/`
2. Invokes `Process.run('tesseract', [tmp, 'stdout', '--psm', '6'])`
3. Reads stdout
4. Cleans up temp file

On a single frame, all 3 can run. This wastes CPU and I/O.

**Current call flow:**
```
_captureNow()
  → _captureFrame()
  → _runScreenOcr(frame)          ← tesseract call #1
  → _analyseFrame(frame)
    → _extractScreenText(frame)   ← tesseract call #2 (same frame!)
  → _updateStuckDetection(frame)
    → _ocrFrame(frame)            ← tesseract call #3 (same frame!)
```

---

### ISSUE V-2: Vision Context Excluded from Regular RAG

**Severity:** P2 — Medium
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/api/chat/turn/prefix.rs:9-10`

**Problem:**
Vision content is unconditionally filtered from the memory prefix:
```rust
if lower.contains("vision:") || lower.contains("objects=[")
    || lower.contains("screen_visible") || lower.contains("camera") { continue; }
```

This means if the user asks "what was I looking at earlier?" or "what did you see on my screen?", the vision memories are invisible to the LLM. The filter should be context-aware (only filter for non-vision queries).

---

### ISSUE V-3: Vision Memories Not Available for Proactive Idle Context

**Severity:** P1 — High
**Files:**
- `AURA-Proj/candle_LNN/aura_lnn/src/vision/store.rs` — `get_recent_visual_context()` exists but is not exposed via FFI
- `AURA-Proj/aura_notebook/lib/services/bar_brain/bar_brain_proactive.dart` — never calls vision context

**Problem:**
The Rust side has `get_recent_visual_context()` which returns recent `vision:` prefixed memory notes. But this function is NOT exposed to Dart via FFI. The proactive system has no way to know what the user was doing before going idle.

---

### ISSUE V-4: OCR Text Not Shared Between Vision Subsystems

**Severity:** P2 — Medium
**Files:**
- `AURA-Proj/aura_notebook/lib/services/vision_service/analysis.dart`
- `AURA-Proj/aura_notebook/lib/services/vision_service/capture.dart`

**Problem:**
`_runScreenOcr()` stores its result in `service._lastScreenText`, but `_extractScreenText()` in `analysis.dart` runs its own independent tesseract call. The two systems don't share OCR results. Additionally, `_ocrFrame()` in `ocr_stuck.dart` runs yet another independent call.

---

### ISSUE V-5: Screenshot Capture Writes Temp Files Without Cleanup

**Severity:** P3 — Low
**File:** `AURA-Proj/aura_notebook/lib/services/vision_service/linux_capture.dart`

**Problem:**
Each screenshot creates a temp file at `/tmp/_aura_screenshot_<timestamp>.jpg` that is never cleaned up. Over time, this accumulates thousands of files.

---

## Memory System Issues

### ISSUE M-1: No Fact Categories — All Facts Treated Equally

**Severity:** P2 — Medium
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/facts.rs`

**Problem:**
All facts are stored in a single `facts` table with no category distinction:
- "User's name is Pratay" (identity — always relevant)
- "User likes coding" (preference — usually relevant)
- "User mentioned debugging a React app yesterday" (activity — rarely relevant for proactive)
- "User's birthday is March 15" (identity — rarely relevant for casual check-ins)

All get the same treatment in `get_facts_strings()` and `get_proactive_context()`.

---

### ISSUE M-2: Proactive Context Budget Allocation is Inverted

**Severity:** P2 — Medium
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/retrieval.rs:191-193`

**Problem:**
```rust
const FACT_BUDGET: usize = 220;    // User facts get the LARGEST budget
const SUMMARY_BUDGET: usize = 200; // Conversation summary
const TURN_BUDGET: usize = 240;    // Recent turns
```

For conversational proactive prompts, facts should have ZERO budget. The budget should go to recent activity (vision context, last turns, summary).

---

### ISSUE M-3: Consecutive Memory Guard Doesn't Apply to Proactive

**Severity:** P3 — Low
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/recall.rs`

**Problem:**
`ConsecutiveMemoryGuard` prevents the same memory from being injected 3+ consecutive turns in regular chat. But proactive prompts bypass this guard entirely by using `get_proactive_context()` directly. If the same facts are always the "top 4", they get injected into every proactive prompt.

---

### ISSUE M-4: Fact Extraction Rules Generate Too Many Activity Facts

**Severity:** P2 — Medium
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/api/worker_utils/memory.rs`

**Problem:**
The rules engine extracts facts like "User is debugging a React app" or "User mentioned they were tired" from every conversation turn. These activity/casual facts accumulate and get picked up by `get_facts_strings()` for proactive context. They should either:
1. Not be extracted at all (too ephemeral)
2. Be stored in a separate `activity_facts` table excluded from proactive context
3. Have a TTL (time-to-live) and auto-expire

---

### ISSUE M-5: Schedule Facts Leak Pattern is Too Broad

**Severity:** P2 — Medium
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/retrieval.rs:78-86`

**Problem:**
The schedule exclusion filter uses broad LIKE patterns:
```sql
AND fact NOT LIKE '%schedule%'
AND fact NOT LIKE '%Schedule%'
AND fact NOT LIKE '%reminder%'
AND fact NOT LIKE '%remind me%'
```

This can accidentally filter non-schedule facts that happen to contain the word "schedule" (e.g., "User works on their schedule management app").

---

## Multi-Turn Conversation Issues

### ISSUE MT-1: Conversation Recap Always Includes Irrelevant Old Turns

**Severity:** P2 — Medium
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/api/chat/turn/prefix.rs:57-95`

**Problem:**
`build_conversation_recap()` always takes the last 6 turns (3 user/assistant pairs) regardless of topic shifts:

```rust
let start = turns.len().saturating_sub(6);
let recent = &turns[start..];
```

If the user was talking about cooking 4 turns ago and then switched to coding, the recap still includes the cooking turns, which can confuse the model.

---

### ISSUE MT-2: Memory-Recall Fast Path Can Be Too Aggressive

**Severity:** P2 — Medium
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/api/chat/persona_retrieval.rs`

**Problem:**
`match_memory_recall()` uses cosine similarity >= 0.65 to skip the LLM entirely for recall queries. But some non-recall queries can hit this threshold:
- "What do you think about names?" (similar to "what is my name")
- "Do you remember when we talked about X?" (similar to recall pattern)
- "Tell me about remembering things" (meta-question about memory)

When caught by the fast path, the response is a mechanical "Your name is X" instead of a thoughtful answer.

---

### ISSUE MT-3: Response Length Collapse in Multi-Turn

**Severity:** P2 — Medium
**Source:** `bug_findings_log.md:64-71`

**Problem:**
Documented behavior: Turn 1 produces 494 chars, Turn 2 produces 534 chars, Turn 3 drops to 158 chars. The response length collapses as the conversation progresses.

**Root cause:** The `plan_reply()` function classifies prompt complexity, and as the KV cache fills with multi-turn context, the available token budget shrinks. Combined with the `RESET_MARGIN_FRAC: 8` watermark in `generate.rs:85`, the context reset happens and the model loses conversational momentum.

---

### ISSUE MT-4: Topic Shift Not Detected in Memory Injection

**Severity:** P3 — Low
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/api/chat/turn/memory.rs`

**Problem:**
`gather_memories()` retrieves facts and semantic RAG hits without considering whether the user has shifted topics. If the user was talking about their cat and then asks about coding, the cat facts still get injected into the memory prefix.

The `ConsecutiveMemoryGuard` only prevents the SAME memory from being injected consecutively, but doesn't detect topic shifts to suppress irrelevant memories.

---

### ISSUE MT-5: KV Cache Reset Loses All Conversation State

**Severity:** P2 — Medium
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/llama_engine/generate.rs:79-97`

**Problem:**
When `n_past` hits the watermark (7/8 of n_ctx), the KV cache is completely cleared:
```rust
if should_reset {
    self.reset_state();
    self.warmup()?;  // Only re-warms system prompt
}
```

After reset, the model only has the system prompt + the current turn's text (which includes `build_conversation_recap()` with 6 turns). But the nuanced conversational state — tone, emotional context, ongoing threads — is lost.

The `build_conversation_recap()` mitigation helps, but 6 turns of clipped text (100 chars each = 600 chars) is a lossy compression of the full conversation.

---

## RL Bandit Issues

### ISSUE RL-1: Engagement Signal is Binary — No Quality Distinction

**Severity:** P1 — High
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/bandit.rs:22-35`

**Problem:**
```rust
pub fn record_engagement(&self, trigger_id: i64, engaged: bool) -> Result<()> {
    let reward = if engaged { 1.0 } else { 0.0 };
    // ...
}
```

Engagement is binary: if the user responds within 30 seconds, `engaged = true` (reward = 1.0). This means:
- "Yeah I'm good!" → engaged = true → reinforces trigger
- "Stop talking about my name!" → engaged = true → reinforces trigger
- "Shut up" → engaged = true → reinforces trigger
- (silence) → engaged = false → punishes trigger

The bandit has no way to distinguish positive engagement from negative engagement. If a user responds negatively to fact-regurgitation, the bandit learns that fact-regurgitation is "engaging" and does it more.

---

### ISSUE RL-2: All Triggers Start with Same Engagement Score

**Severity:** P2 — Medium
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/core.rs:144-152`

**Problem:**
All 8 triggers start with `engagement_score = 1.0` (the DEFAULT). Since the bandit uses softmax over engagement scores, all triggers have equal probability initially. Combined with Issue P-2 (bad trigger labels), the bandit explores labels that naturally cause fact-regurgitation and, because users respond (even negatively), reinforces them.

---

### ISSUE RL-3: Softmax Temperature is Too Low

**Severity:** P3 — Low
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/bandit.rs:50`

**Problem:**
```rust
const SOFTMAX_TAU: f64 = 0.35;
```

With tau = 0.35, the softmax is very sharp — small differences in engagement_score get amplified. After a few iterations, one trigger can dominate. Combined with the binary engagement signal (Issue RL-1), a trigger that happens to get a few responses in a row quickly becomes the overwhelming favorite.

---

### ISSUE RL-4: Recency Penalty is Commented Out / No-Op

**Severity:** P2 — Medium
**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/bandit.rs:99-106`

**Problem:**
```rust
.map(|(_id, _label, score, _shown)| {
    let age = now_secs.max(1) as f64; // placeholder; recency handled by cooldown
    let _ = age;  // ← NO-OP! age is computed but never used
    (*score).max(SCORE_FLOOR)
})
```

The recency penalty is computed but immediately discarded with `let _ = age;`. This means the softmax is purely score-based with no recency decay. A trigger with a high engagement score can dominate forever, regardless of how recently it fired (the cooldown only prevents firing within 5 minutes, but after that, the high-score trigger is always preferred).

---

### ISSUE RL-5: No Anti-Regurgitation Reward Shaping

**Severity:** P1 — High
**File:** System-wide (no single file)

**Problem:**
The bandit optimizes for "user responded" but has no signal for "response quality." There is no mechanism to:
1. Detect if the response contained user facts (negative reward)
2. Detect if the response was SILENT (neutral — should not affect scores)
3. Detect if the response was natural/conversational (positive reward)

The RL loop is optimizing for the wrong objective.

---

## Priority Matrix

| Priority | Issue | Category | Impact | Effort | Description |
|----------|-------|----------|--------|--------|-------------|
| **P0** | P-1 | Proactive | Critical | Medium | Proactive prompt dumps raw user facts |
| **P0** | P-2 | Proactive | Critical | Low | Trigger labels are fact-dump seeds |
| **P1** | P-3 | Proactive | High | Low | Proactive prompt instruction too weak |
| **P1** | P-4 | Proactive | High | Low | Idle trigger has no activity context |
| **P1** | P-5 | Proactive | High | Low | Idle trigger fires too frequently |
| **P1** | V-3 | Vision | High | Low | Vision context not available for proactive |
| **P1** | RL-1 | RL Bandit | High | Medium | Engagement signal is binary |
| **P1** | RL-5 | RL Bandit | High | Medium | No anti-regurgitation reward shaping |
| **P2** | P-6 | Proactive | Medium | Low | Clock vs bandit template inconsistency |
| **P2** | V-1 | Vision | Medium | Medium | Triple tesseract invocation |
| **P2** | V-2 | Vision | Medium | Low | Vision excluded from regular RAG |
| **P2** | V-4 | Vision | Medium | Medium | OCR text not shared between subsystems |
| **P2** | M-1 | Memory | Medium | Medium | No fact categories |
| **P2** | M-2 | Memory | Medium | Low | Proactive context budget inverted |
| **P2** | M-4 | Memory | Medium | Medium | Too many activity facts extracted |
| **P2** | M-5 | Memory | Medium | Low | Schedule filter too broad |
| **P2** | MT-1 | MultiTurn | Medium | Medium | Recap includes irrelevant old turns |
| **P2** | MT-2 | MultiTurn | Medium | Medium | Recall fast path too aggressive |
| **P2** | MT-3 | MultiTurn | Medium | Hard | Response length collapse in multi-turn |
| **P2** | MT-5 | MultiTurn | Medium | Hard | KV cache reset loses conversation state |
| **P2** | RL-2 | RL Bandit | Medium | Low | All triggers start with same score |
| **P2** | RL-4 | RL Bandit | Medium | Low | Recency penalty is a no-op |
| **P3** | V-5 | Vision | Low | Low | Temp files not cleaned up |
| **P3** | M-3 | Memory | Low | Low | Consecutive guard doesn't apply to proactive |
| **P3** | MT-4 | MultiTurn | Low | Medium | Topic shift not detected in memory injection |
| **P3** | RL-3 | RL Bandit | Low | Low | Softmax temperature too low |

---

## Step-by-Step Fix Guide

### Phase 1: Fix Proactive Spam (P0 — Do First)

#### Step 1.1: Rewrite `_buildProactivePrompt()` to stop injecting facts

**File:** `AURA-Proj/aura_notebook/lib/services/bar_brain/bar_brain_proactive.dart`

Replace lines 87-147 with:

```dart
Future<String> _buildProactivePrompt(
  String label,
  String type,
  Map<String, dynamic> data,
) async {
  final buffer = StringBuffer();

  // Clock-based greetings: clean template, no context
  if (type == 'clock' || label == 'morning_greeting' ||
      label == 'afternoon_checkin' || label == 'evening_winddown') {
    final greeting = switch (label) {
      'morning_greeting' => 'Good morning',
      'afternoon_checkin' => 'Good afternoon',
      'evening_winddown' => 'Good evening',
      _ => 'Hello',
    };
    buffer.writeln('Say a brief, warm $greeting to the user.');
    buffer.writeln('Reply in 1-2 sentences. Be natural and friendly.');
    buffer.writeln('Do NOT mention any previous conversations, stored facts, names, birthdays, or context.');
    return buffer.toString().trim();
  }

  // Schedule reminders: include the reminder text
  if (label == 'schedule_reminder') {
    final event = data['event'];
    final summary = event is Map ? event['summary']?.toString() : null;
    buffer.writeln('AURA has a reminder for the user.');
    if (summary != null && summary.isNotEmpty) {
      buffer.writeln('  reminder=$summary');
    }
    buffer.writeln('Deliver the reminder naturally and briefly. 1-2 sentences.');
    return buffer.toString().trim();
  }

  // All other triggers (idle, bandit, natural context): conversational only
  buffer.writeln('AURA is being proactive. Say something brief and warm.');

  // Idle triggers: include what the user was last doing (from vision)
  if (label == 'idle_checkin') {
    final idleMins = DateTime.now()
        .difference(AuraBarBrain.instance.lastUserInteraction)
        .inMinutes;
    buffer.writeln('  The user has been idle for $idleMins minutes.');

    // Include last vision activity if available
    try {
      final visionContext = await auraGetRecentVisualContext();
      if (visionContext.isNotEmpty) {
        buffer.writeln('  Before going idle, the user was: $visionContext');
      }
    } catch (_) {}
  }

  // Natural context triggers: include the observed event
  final event = data['event'];
  if (event is Map) {
    final summary = event['summary']?.toString();
    if (summary != null && summary.isNotEmpty) {
      buffer.writeln('  Observed: $summary');
    }
  }

  // Explicit anti-fact-regurgitation instructions
  buffer.writeln('');
  buffer.writeln('RULES:');
  buffer.writeln('- Speak like a friend casually checking in.');
  buffer.writeln('- Do NOT mention user names, birthdays, preferences, or any stored facts.');
  buffer.writeln('- Do NOT say "I remember" or reference previous conversations.');
  buffer.writeln('- Keep it to 1-2 short sentences.');
  buffer.writeln('- If there is no good reason to interrupt, reply exactly: SILENT');

  return buffer.toString().trim();
}
```

#### Step 1.2: Rewrite trigger labels to be conversational starters

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/core.rs`

Replace lines 144-152:

```rust
let initial_triggers = vec![
    (1, "Hey, just checking in — how are you doing?"),
    (2, "You've been quiet for a bit. Everything okay?"),
    (3, "Just wanted to say hey. What's up?"),
    (4, "I'm here if you need anything."),
    (5, "Hey! What are you up to?"),
    (6, "Looks like you stepped away. Take your time."),
    (7, "Just floating by — need anything?"),
    (8, "Hey there. How's it going?"),
];
```

Add migration for existing DBs (after the seed block):

```rust
let _ = conn.execute(
    "UPDATE triggers SET label = CASE trigger_id
        WHEN 1 THEN 'Hey, just checking in — how are you doing?'
        WHEN 2 THEN 'You have been quiet for a bit. Everything okay?'
        WHEN 3 THEN 'Just wanted to say hey. Whats up?'
        WHEN 4 THEN 'I am here if you need anything.'
        WHEN 5 THEN 'Hey! What are you up to?'
        WHEN 6 THEN 'Looks like you stepped away. Take your time.'
        WHEN 7 THEN 'Just floating by — need anything?'
        WHEN 8 THEN 'Hey there. How is it going?'
        ELSE label END
    WHERE trigger_id BETWEEN 1 AND 8",
    [],
);
```

#### Step 1.3: Add anti-regurgitation rules to system prompt

**File:** `AURA-Proj/candle_LNN/aura_lnn/examples/persona_cases/system_prompt.txt`

Add after the ABSOLUTE RULES section:

```
PROACTIVE RULES (when "AURA is being proactive" appears in the prompt):
- Speak naturally like a friend checking in. Casual, warm, brief.
- NEVER recite stored user facts (names, birthdays, preferences, locations) unless the user explicitly asked.
- NEVER say "I remember" followed by a stored fact.
- NEVER mention "trigger", "label", "context", "memory_context", or any internal metadata.
- If you have nothing meaningful to say, reply exactly: SILENT
```

#### Step 1.4: Expose `get_recent_visual_context()` via FFI

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/api/vision.rs`

Add:

```rust
pub fn aura_get_recent_visual_context() -> String {
    let store = match crate::api::engine::get_store() {
        Some(s) => s,
        None => return String::new(),
    };
    match store.get_recent_visual_context(1) {
        Ok(events) => events.first().cloned().unwrap_or_default(),
        Err(_) => String::new(),
    }
}
```

**File:** `AURA-Proj/aura_notebook/lib/src/rust/api/vision.dart`

The FRB auto-generator will create the Dart binding. Use it in `_buildProactivePrompt()`.

---

### Phase 2: Fix RL Bandit (P1)

#### Step 2.1: Add sentiment-aware engagement tracking

**File:** `AURA-Proj/aura_notebook/lib/services/bar_brain/bar_brain_proactive.dart`

Modify the engagement window to detect negative responses:

```dart
void _evaluateEngagementResponse(String userText, int triggerId, String type) {
  _engagementTimer?.cancel();
  final lower = userText.toLowerCase().trim();

  // Negative sentiment: user is annoyed
  final isNegative = lower.contains('stop') ||
      lower.contains('shut up') ||
      lower.contains('not now') ||
      lower.contains('go away') ||
      lower.contains('leave me alone') ||
      lower.contains('annoying') ||
      lower.contains('spam') ||
      lower.contains('dont do that') ||
      lower.contains("don't do that");

  // Low-effort response: not real engagement
  final isLowEffort = lower.length < 4 || lower == 'ok' || lower == 'k' || lower == 'ok.';

  final engaged = !isNegative && !isLowEffort;
  _recordEngagement(triggerId, engaged: engaged, type: type);
}
```

#### Step 2.2: Fix the no-op recency penalty in bandit

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/bandit.rs`

Replace lines 99-106:

```rust
let mut probs: Vec<f64> = candidates
    .iter()
    .map(|(_id, _label, score, _shown)| {
        // Actual recency penalty: triggers fired recently get lower scores
        // _last_fired is already filtered by cooldown, but within the eligible
        // set, older triggers get a gentle boost.
        let last_fired_secs = conn.query_row(
            "SELECT last_fired FROM triggers WHERE trigger_id = ?",
            [_id],
            |r| r.get::<_, i64>(0),
        ).unwrap_or(0);
        let age_secs = (now_secs - last_fired_secs).max(1) as f64;
        let recency_bonus = (age_secs / 600.0).min(0.3); // max 0.3 bonus for 10+ min old
        (*score + recency_bonus).max(SCORE_FLOOR)
    })
    .collect();
```

#### Step 2.3: Increase softmax temperature for more exploration

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/bandit.rs:50`

```rust
const SOFTMAX_TAU: f64 = 0.5; // was 0.35 — increase for more exploration
```

---

### Phase 3: Fix Vision Integration (P1-P2)

#### Step 3.1: Deduplicate tesseract calls

**File:** `AURA-Proj/aura_notebook/lib/services/vision_service/capture.dart`

Modify `_captureNow()` to run OCR once and share the result:

```dart
Future<void> _captureNow(VisionService service, {required String reason}) async {
  final frame = await _captureFrame(service);
  if (frame == null) return;

  // Single OCR pass — shared across all subsystems
  String? ocrText;
  if (Platform.isLinux) {
    ocrText = await _runScreenOcr(frame);
    if (ocrText != null && ocrText.isNotEmpty) {
      service._lastScreenText = ocrText;
    }
  }

  // Pass pre-computed OCR to analysis (skip redundant tesseract call)
  final detections = await _analyseFrame(service, frame, precomputedOcr: ocrText);

  // Pass pre-computed OCR to stuck detection (skip redundant tesseract call)
  await _updateStuckDetection(service, frame, precomputedOcr: ocrText);
}
```

**File:** `AURA-Proj/aura_notebook/lib/services/vision_service/analysis.dart`

Modify `_analyseFrame()` signature:

```dart
Future<List<VisionDetection>> _analyseFrame(
  VisionService service,
  Uint8List frame, {
  String? precomputedOcr,
}) async {
  // ... existing logic ...

  // Use pre-computed OCR instead of calling tesseract again
  final screenText = precomputedOcr ?? await _extractScreenText(frame);

  // ... rest of analysis ...
}
```

**File:** `AURA-Proj/aura_notebook/lib/services/vision_service/ocr_stuck.dart`

Modify `_updateStuckDetection()` signature:

```dart
Future<void> _updateStuckDetection(
  VisionService service,
  Uint8List frame, {
  String? precomputedOcr,
}) async {
  final text = precomputedOcr ?? await _ocrFrame(service, frame);
  // ... rest of stuck detection ...
}
```

#### Step 3.2: Make vision filtering in prefix.rs context-aware

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/api/chat/turn/prefix.rs`

Change `build_memory_prefix()` to accept `is_vision_query`:

```rust
pub fn build_memory_prefix(memories: &[String], is_vision_query: bool) -> Option<String> {
    let mut facts: Vec<String> = Vec::new();

    for m in memories {
        let lower = m.to_lowercase();
        if lower.starts_with("summary:") { continue; }

        // Only filter vision content for non-vision queries
        if !is_vision_query {
            if lower.contains("vision:") || lower.contains("objects=[")
                || lower.contains("screen_visible") || lower.contains("camera") { continue; }
        }

        if lower.contains("schedule request:") || lower.contains("schedule:") { continue; }
        // ... rest unchanged ...
    }
    // ...
}
```

Update call sites in `turn.rs` to pass `class.is_vision_query`.

#### Step 3.3: Clean up temp screenshot files

**File:** `AURA-Proj/aura_notebook/lib/services/vision_service/linux_capture.dart`

Add cleanup after capture:

```dart
// After reading the file bytes:
final bytes = await File(tmp).readAsBytes();
try { await File(tmp).delete(); } catch (_) {} // cleanup
```

---

### Phase 4: Fix Memory System (P2)

#### Step 4.1: Add fact categories

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/core.rs`

Add migration:

```rust
let _ = conn.execute(
    "ALTER TABLE facts ADD COLUMN category TEXT NOT NULL DEFAULT 'identity'",
);
```

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/facts.rs`

Add categorization:

```rust
pub fn categorize_fact(fact: &str) -> &'static str {
    let lower = fact.to_lowercase();
    if lower.starts_with("user's name is") || lower.starts_with("user has brother")
        || lower.starts_with("user has sister") || lower.starts_with("user has mom")
        || lower.starts_with("user has dad") || lower.contains("birthday")
    {
        "identity"
    } else if lower.contains("likes ") || lower.contains("loves ")
        || lower.contains("enjoys ") || lower.contains("prefers ")
        || lower.contains("favorite")
    {
        "preference"
    } else if lower.contains("is working on") || lower.contains("is debugging")
        || lower.contains("is learning") || lower.contains("mentioned")
    {
        "activity"
    } else {
        "identity" // default
    }
}
```

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/retrieval.rs`

Modify `get_proactive_context()` to exclude `activity` facts:

```rust
"SELECT fact FROM facts
 WHERE fact NOT LIKE 'vision:%'
   AND fact NOT LIKE '%schedule%'
   AND category != 'activity'
 ORDER BY timestamp DESC LIMIT 4",
```

#### Step 4.2: Add exponential backoff to idle trigger

**File:** `AURA-Proj/aura_notebook/lib/services/proactive_scheduler/service.dart`

Add field:

```dart
int _idleTriggerCount = 0;
```

Add method:

```dart
Duration _idleBackoff() {
  final multiplier = _idleTriggerCount.clamp(1, 3);
  return Duration(minutes: 20 * multiplier);
}
```

Modify idle check in `trigger_logic.dart`:

```dart
if (idle >= ProactiveScheduler.idleThreshold) {
  if (_lastIdleTrigger == null ||
      now.difference(_lastIdleTrigger!) >= _idleBackoff()) {
    _lastIdleTrigger = now;
    _idleTriggerCount++;
    await _triggerProactive(_wrapTrigger(ProactiveScheduler._kIdleId, "idle_checkin", "idle"));
    return;
  }
}
```

Reset in `processUserPrompt()`:

```dart
_idleTriggerCount = 0;
```

---

### Phase 5: Fix Multi-Turn (P2)

#### Step 5.1: Topic-shift-aware conversation recap

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/api/chat/turn/prefix.rs`

Modify `build_conversation_recap()`:

```rust
pub fn build_conversation_recap(memories: &[String]) -> Option<String> {
    let mut turns: Vec<(String, String)> = Vec::new();
    // ... existing parsing ...

    if turns.is_empty() { return None; }

    let start = turns.len().saturating_sub(6);
    let recent = &turns[start..];

    // Topic shift detection: if the last user turn has <20% word overlap
    // with the turn 3 positions earlier, treat it as a topic shift.
    let effective = if recent.len() >= 6 {
        let old_words: std::collections::HashSet<&str> = recent[0].1
            .split_whitespace()
            .filter(|w| w.len() > 3)
            .collect();
        let new_words: std::collections::HashSet<&str> = recent[recent.len()-2].1
            .split_whitespace()
            .filter(|w| w.len() > 3)
            .collect();
        let overlap = old_words.intersection(&new_words).count();
        let total = old_words.len().max(new_words.len()).max(1);
        if (overlap as f64 / total as f64) < 0.2 && total > 3 {
            // Topic shifted — only keep turns after the shift
            &recent[recent.len()-3..]
        } else {
            recent
        }
    } else {
        recent
    };

    let mut lines = Vec::new();
    for (speaker, content) in effective {
        lines.push(format!("{speaker}: {content}"));
    }
    Some(format!("[Recent chat:\n{}\n]\n", lines.join("\n")))
}
```

#### Step 5.2: Tighten recall fast path threshold

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/api/chat/persona_retrieval.rs`

Increase threshold from 0.65 to 0.75:

```rust
const MEMORY_RECALL_THRESHOLD: f64 = 0.75; // was 0.65
```

Add a secondary check: only use fast path if the matched example is actually a recall query (check the prompt for recall keywords):

```rust
pub fn match_memory_recall(&self, prompt: &str) -> Option<String> {
    let lower = prompt.to_lowercase();
    // Only attempt fast path for actual recall queries
    let is_recall = lower.contains("my name") || lower.contains("who am i")
        || lower.contains("how old") || lower.contains("my age")
        || lower.contains("birthday") || lower.contains("remember")
        || lower.contains("do i have") || lower.contains("what do i like")
        || lower.contains("where do i live") || lower.contains("allergic");
    if !is_recall { return None; }
    // ... rest of matching logic ...
}
```

---

### Phase 6: Hardening (P3)

#### Step 6.1: Add proactive response quality check

**File:** `AURA-Proj/aura_notebook/lib/services/bar_brain/bar_brain_generation.dart`

After generation completes, check if the response leaked user facts:

```dart
bool _containsLeakedFacts(String response, String? memoryContext) {
  if (memoryContext == null || memoryContext.isEmpty) return false;
  // Check if response contains phrases from the memory context
  final facts = memoryContext
      .split('\n')
      .where((l) => l.startsWith('- '))
      .map((l) => l.substring(2).toLowerCase().trim())
      .where((f) => f.length > 10);
  for (final fact in facts) {
    if (response.toLowerCase().contains(fact)) return true;
  }
  return false;
}
```

If leaked facts detected, suppress the response (treat as SILENT).

#### Step 6.2: Add proactive log quality metrics

**File:** `AURA-Proj/candle_LNN/aura_lnn/src/memory/store/bandit.rs`

Extend `proactive_log` table:

```sql
ALTER TABLE proactive_log ADD COLUMN response_quality TEXT DEFAULT 'unknown';
-- Values: 'positive', 'negative', 'silent', 'leaked_facts', 'unknown'
```

Log quality alongside engagement for future RL improvements.

---

## Testing Checklist

After implementing fixes, verify:

- [ ] Idle proactive trigger says something like "Hey, everything okay?" NOT "Hey Pratay, I remember your birthday"
- [ ] Clock triggers (morning/afternoon/evening) are clean greetings without fact references
- [ ] Bandit triggers are conversational starters, not fact dumps
- [ ] Schedule reminders deliver the reminder text naturally
- [ ] Vision-based proactive (stuck screen, gesture) uses activity context
- [ ] RL engagement tracks negative responses as non-engaged
- [ ] Idle trigger backs off after 3 consecutive idle pings
- [ ] Regular chat "what was I looking at?" includes vision memories
- [ ] Tesseract only runs once per frame capture
- [ ] Multi-turn conversation recap drops old topics on topic shift
- [ ] Recall fast path only triggers for actual recall queries

---

## Files Modified Summary

| File | Changes |
|------|---------|
| `aura_notebook/lib/services/bar_brain/bar_brain_proactive.dart` | Rewrite `_buildProactivePrompt()`, add sentiment-aware engagement |
| `candle_LNN/aura_lnn/src/memory/store/core.rs` | New trigger labels, migration |
| `candle_LNN/aura_lnn/src/memory/store/bandit.rs` | Fix recency penalty, increase tau, add quality metrics |
| `candle_LNN/aura_lnn/src/memory/store/retrieval.rs` | Add `get_proactive_context_conversational()`, fix fact filtering |
| `candle_LNN/aura_lnn/src/memory/store/facts.rs` | Add fact categorization |
| `candle_LNN/aura_lnn/src/api/chat/turn/prefix.rs` | Context-aware vision filtering, topic-shift recap |
| `candle_LNN/aura_lnn/src/api/chat/persona_retrieval.rs` | Tighten recall threshold |
| `candle_LNN/aura_lnn/src/api/vision.rs` | Expose `aura_get_recent_visual_context()` |
| `candle_LNN/aura_lnn/examples/persona_cases/system_prompt.txt` | Add proactive rules |
| `aura_notebook/lib/services/vision_service/capture.dart` | Deduplicate tesseract |
| `aura_notebook/lib/services/vision_service/analysis.dart` | Accept precomputed OCR |
| `aura_notebook/lib/services/vision_service/ocr_stuck.dart` | Accept precomputed OCR |
| `aura_notebook/lib/services/vision_service/linux_capture.dart` | Cleanup temp files |
| `aura_notebook/lib/services/proactive_scheduler/service.dart` | Idle backoff |
| `aura_notebook/lib/services/proactive_scheduler/trigger_logic.dart` | Idle backoff logic |
| `aura_notebook/lib/services/bar_brain/bar_brain_generation.dart` | Fact leak detection |

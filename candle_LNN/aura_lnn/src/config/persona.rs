// ── LATENCY NOTE ─────────────────────────────────────────────────────────────
// This prompt is decoded from scratch on EVERY chat turn (the chat model is
// recurrent — Gated Delta Net — so there is no cached prompt-state across
// turns) and re-warmed from zero on every context-window reset. Its token
// count is therefore the single biggest lever on per-turn latency.
// The canonical text now lives in examples/persona_cases/system_prompt.txt so it
// can be edited without recompiling, but it is still embedded into the binary
// so there is no runtime file-path hunt on Linux or Android.
//
// Re-export the loaded system prompt for callers that already import it.
pub use crate::config::persona_bank::PERSONA_BANK;

pub fn system_prompt() -> &'static str {
    PERSONA_BANK.system_prompt()
}

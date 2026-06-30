// chat_constants.dart
// All shared constants for the AURA chat system.
// ─────────────────────────────────────────────────────────────────────────────

/// The sentinel token Rust emits before the first real token.
const kThinkingSentinel = '\x00__THINKING__\x00';

/// Suggestion chips shown on the empty-state screen.
const kSuggestions = [
  'Tell me a short story ✨',
  'Help me brainstorm 💡',
  'What can you do? 🎈',
  'Show my notebook 📓',
];

/// Messages shorter than this char count go as a single turn.
/// Longer ones get chunked.
const kChunkThreshold = 150;

/// Debounce delay before firing speculative prefill to Rust.
/// We wait this long after the user stops typing before running embed + prefill.
const kPrefillDebounce = Duration(milliseconds: 300);

/// If the user types a new character within this window, "actively typing"
/// stays true. After this much silence, typing state clears.
const kTypingIdleTimeout = Duration(milliseconds: 1500);

/// Minimum word count before the sliding-window gate allows a prefill.
/// Mirrors the ≥6-word gate in Thread A of prefill.rs.
const kMinWordsForPrefill = 4;
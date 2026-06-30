pub const MAX_NEW_TOKENS: usize = 120;
// Temperature lowered from 0.85 → 0.7. At 0.85 the small model freelances
// flourishes ("(P.S.: ...)" postscripts, mid-sentence tangents) and is more
// likely to emit the leaked "AURA:" prefix. 0.7 keeps the warm, slightly
// playful voice the persona asks for without the extra hallucinated asides.
pub const TEMPERATURE: f64 = 0.7;
pub const TOP_P: f64 = 0.95;

pub const REPEAT_PENALTY: f32 = 1.18; // Reduced from 1.55 — too aggressive, caused degeneration
pub const REPEAT_LAST_N: usize = 256; // Expanded window for better coherence
                                      // Token IDs should be queried from the model at runtime, not hardcoded
                                      // These are only fallbacks
pub const FALLBACK_BOS: u32 = 1;
pub const FALLBACK_EOS: u32 = 7;
pub const FALLBACK_IM_START: u32 = 6;
pub const THINKING_SENTINEL: &str = "\x00__THINKING__\x00";

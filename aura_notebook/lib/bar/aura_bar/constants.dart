/// Hard character cap for the AURA Bar's text field. The bar is a small pill
/// meant for quick 1-2 sentence questions; long-form requests belong in the
/// main chat app. This prevents over-typing, and the soft redirect in
/// AuraBarBrain.processUserPrompt (word count + long-form-phrase detection)
/// then nudges long replies to the full app. Matches `maxBarChars` in
/// bar_brain.dart — keep the two in sync.
///
/// 140 chars (~1 short sentence) — Twitter-length. The bar is a pill, not a
/// chat window: anything longer than a quick question is unreadable in one
/// line and belongs in the main app where the user can read a full reply.
const int kBarMaxChars = 140;

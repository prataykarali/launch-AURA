// src/memory/embed/plan_budgets.rs - Level/category → concrete token budgets.
// ──────────────────────────────────────────────────────────────────────────

use super::plan::ReplyPlan;

pub(super) fn category_plan(category: &'static str, is_mobile: bool) -> ReplyPlan {
    // continuation is now a FLAG: 0 = single pass, 1 = LOOP until EOS.
    // The model decides how many turns it needs — not a fixed count.
    let (level, desktop_max, mobile_max, continuation, affect) = match category {
        "greeting" => (0, 40, 28, 0, "calm"),
        "acknowledgement" => (1, 60, 40, 0, "calm"),
        "factual" => (3, 120, 80, 0, "focused"),
        "open_ended" => (4, 96, 48, 1, "focused"),
        "task_coding" => (5, 160, 48, 1, "focused"),
        _ => (2, 96, 64, 0, "calm"),
    };
    ReplyPlan {
        max_tokens: if is_mobile { mobile_max } else { desktop_max },
        continuation,
        level,
        category,
        affect,
        anchor_x: 0.85,
        anchor_y: 0.78,
    }
}

/// Map a level (0-6) to concrete (max_tokens, continuation) per platform.
///
/// Desktop budgets are ~1.5x mobile because the recurrent model's per-token
/// cost is far lower on a desktop CPU. `continuation` is non-zero only for the
/// top levels — a short answer never needs a second pass, but a level-6
/// "explain how X works" is allowed up to 2 continuation loops if the model is
/// still mid-thought at the cap.
pub(super) fn level_plan(level: u8, is_mobile: bool) -> ReplyPlan {
    // (desktop_max, mobile_max, continuation)
    // Continuation passes are multi-turn: each pass is ~1-2 sentences, the
    // model keeps generating from its KV cache (no re-decode). This gives
    // long-form answers (stories, explain) in digestible spoken paragraphs.
    // (desktop_max, mobile_max, continuation)
    // continuation: 0 = single pass, 1 = LOOP until model emits EOS.
    const TABLE: &[(i32, i32, u8)] = &[
        (48, 32, 0), // 0: greeting / ack
        (96, 48, 0), // 1: identity / preference
        (160, 72, 0), // 2: simple Q / banter
        (256, 112, 0), // 3: real question
        (96, 48, 1), // 4: detailed Q — loop on mobile
        (160, 48, 1), // 5: deep Q / list — loop on mobile
        (96, 48, 1), // 6: explain / write — loop on mobile
    ];
    let idx = (level as usize).min(TABLE.len() - 1);
    let (dmax, mmax, cont) = TABLE[idx];
    let max_tokens = if is_mobile { mmax } else { dmax };
    ReplyPlan {
        max_tokens,
        continuation: cont,
        level,
        category: match level {
            0 => "greeting",
            1 => "acknowledgement",
            2 | 3 => "factual",
            4 => "open_ended",
            _ => "task_coding",
        },
        affect: if level >= 3 { "focused" } else { "calm" },
        anchor_x: 0.85,
        anchor_y: 0.78,
    }
}

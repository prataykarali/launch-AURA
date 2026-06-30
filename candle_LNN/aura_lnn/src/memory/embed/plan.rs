// src/memory/embed/plan.rs - Response-length planner (variable verbosity).
//
// "The embedder decides how many turns AURA should take to reply" — implemented
// as a deterministic complexity classifier that reads the user message and
// returns a `ReplyPlan`: how long the first generation pass should be, and how
// many continuation (multi-loop) passes the engine should run if the model is
// still mid-thought at the token cap.
//
// We do NOT re-purpose the 110MB bge ONNX model for classification — it's a
// sentence embedder, not a classifier, and running it twice per turn would
// double RAG latency. Instead the planner combines the SAME cheap signals the
// brain uses to understand a message (length, question type, instruction
// verbs, code/math markers, follow-up cues) into 7 discrete "vibe" levels.
// These map to concrete token budgets so a "hi" gets ~1 sentence and an
// "explain how transformers work" gets a multi-paragraph, multi-pass answer.
//
// The levels are tuned to the 1.2B model's sweet spot: short enough to stay
// coherent and low-latency, long enough that an "explain X" actually explains.
// ──────────────────────────────────────────────────────────────────────────

use super::plan_budgets::{category_plan, level_plan};

/// AURA's plan for how long this reply should be.
///
/// `max_tokens`   — per-pass token cap (first generation pass).
/// `continuation` — how many EXTRA multi-loop passes to run if the model hits
///   the cap mid-sentence and there's clearly more to say. 0 = single pass.
///   Each continuation re-injects the partial output so the model continues.
#[derive(Clone, Copy, Debug)]
pub struct ReplyPlan {
    pub max_tokens: i32,
    pub continuation: u8,
    /// Human label for diagnostics (logged by the worker).
    pub level: u8,
    /// Coarse message category that chose the token budget.
    pub category: &'static str,
    /// Future extension hook for character animation.
    pub affect: &'static str,
    /// Future extension hook for character placement on screen.
    pub anchor_x: f32,
    pub anchor_y: f32,
}

impl ReplyPlan {
    /// Total token ceiling across all passes (max_tokens * (1 + continuation)).
    /// Capped so a runaway planner can't blow up the context window.
    pub fn total_ceiling(&self) -> i32 {
        (self.max_tokens as u32 * (1 + self.continuation as u32)).min(4096) as i32
    }
}

/// Classify a user message into a reply plan.
///
/// `is_mobile` scales every budget down — the recurrent model re-decodes the
/// whole context per token, so long answers on a 4-thread phone are slow. The
/// RELATIVE differences between levels are preserved on both platforms (a
/// greeting is always short, an explain is always the longest).
pub fn plan_reply(prompt: &str, is_mobile: bool) -> ReplyPlan {
    let p = prompt.trim();
    let lower = p.to_lowercase();
    let word_count = p.split_whitespace().filter(|w| !w.is_empty()).count();
    let char_count = p.chars().count();

    // ── Lexical signals ───────────────────────────────────────────────────
    // Each signal contributes "complexity points". The final level is the
    // bucket the points fall into. This is deliberately transparent: every
    // lever on the length is visible here, no hidden weights.
    let mut score: u32 = 0;

    // 1. Length: longer messages usually want longer answers.
    if word_count >= 40 {
        score += 4;
    } else if word_count >= 20 {
        score += 3;
    } else if word_count >= 10 {
        score += 2;
    } else if word_count >= 5 {
        score += 1;
    }

    // 2. Deep-instruction verbs: "explain", "describe", "write", "teach me".
    //    These almost always need a multi-sentence, multi-paragraph answer.
    const DEEP_VERBS: &[&str] = &[
        "explain",
        "describe",
        "write ",
        "write me",
        "tell me about",
        "tell me a",
        "teach me",
        "walk me through",
        "break down",
        "break it down",
        "summarize the ",
        "elaborate",
        "give me an example of",
        "how does",
        "how do",
        "how would",
        "how could",
        "how should",
        "why does",
        "why do",
        "why is",
        "why are",
        "why would",
        "what is the difference",
        "compare",
        "contrast",
    ];
    let deep_verb = DEEP_VERBS.iter().any(|v| lower.contains(v));
    if deep_verb {
        score += 4;
    }

    // 3. Shallow-question verbs: "what is X", "who is", "when", "where".
    //    These want a real answer but not a lecture.
    const SHALLOW_Q: &[&str] = &[
        "what is ",
        "what are ",
        "what's ",
        "who is ",
        "who's ",
        "when ",
        "where ",
        "which ",
    ];
    if SHALLOW_Q.iter().any(|v| lower.contains(v)) {
        score += 2;
    }

    // 4. Greetings / acknowledgements — the floor. These override everything
    //    to level 0 (ultra-short). Detected FIRST so "hi, explain X" still
    //    classifies as a greeting's intent is acknowledged but the explain wins.
    //    We only force level 0 if the message is SHORT and mostly a greeting.
    let is_plain_greeting = word_count <= 4
        && (matches!(
            lower.as_str(),
            "hi" | "hey" | "hello" | "yo" | "sup" | "hiya" | "hi!" | "hey!" | "hello!"
        ) || lower.starts_with("hi ")
            || lower.starts_with("hey ")
            || lower.starts_with("hello ")
            || lower.starts_with("yo ")
            || lower.starts_with("sup ")
            || lower.starts_with("good morning")
            || lower.starts_with("good evening")
            || lower.starts_with("good afternoon")
            || lower.starts_with("good night")
            || lower.starts_with("thanks")
            || lower.starts_with("thank you")
            || lower.starts_with("bye")
            || lower.starts_with("ok")
            || lower.starts_with("okay")
            || lower.starts_with("cool")
            || lower.starts_with("nice")
            || lower.starts_with("lol")
            || lower.starts_with("lmao")
            || lower.starts_with("haha")
            || lower.starts_with("hahaha")
            || lower.starts_with("k")
            || lower.starts_with("kk")
            || lower.starts_with("got it")
            || lower.starts_with("i see")
            || lower.starts_with("right")
            || lower.starts_with("yeah")
            || lower.starts_with("yes")
            || lower.starts_with("nope")
            || lower.starts_with("yep")
            || lower.starts_with("no "));
    if is_plain_greeting {
        return category_plan("greeting", is_mobile);
    }

    // 5. Identity statements ("i'm pratay", "my name is X") — short
    //    warm acknowledgement, 1-2 sentences. Names are universal and need a
    //    tight budget so AURA doesn't over-explain. Preferences are handled by
    //    the general planner and the system-prompt memory rule instead of a
    //    hardcoded list.
    let is_identity_like = char_count < 60
        && (lower.starts_with("my name is")
            || lower.starts_with("call me")
            || lower.starts_with("i'm ")
            || lower.starts_with("im ")
            || lower.starts_with("i am ")
            || lower.starts_with("you can call me"));
    if is_identity_like {
        return category_plan("acknowledgement", is_mobile);
    }

    let is_task_context = lower.contains("code")
        || lower.contains("coding")
        || lower.contains("debug")
        || lower.contains("bug")
        || lower.contains("function")
        || lower.contains("script")
        || lower.contains("regex")
        || lower.contains("sql")
        || lower.contains("algorithm")
        || lower.contains("implement")
        || lower.contains("refactor")
        || lower.contains("stack trace")
        || lower.contains("terminal")
        || lower.contains("rust")
        || lower.contains("dart")
        || lower.contains("flutter");

    // 6. Code / math / structured output — bump to a higher level so the model
    //    has room to actually produce the artifact.
    if is_task_context
        || lower.contains("equation")
        || lower.contains("formula")
        || lower.contains("calculate")
        || lower.contains("solve")
    {
        score += 3;
    }

    // 7. "List" / "steps" / "examples" requests — want structured length.
    if lower.contains("list")
        || lower.contains("steps")
        || lower.contains("examples")
        || lower.contains("reasons")
        || lower.contains("ways to")
    {
        score += 2;
    }

    // 8. Multi-clause / multi-sentence input (comma + and/but) signals the
    //    user wrote a real question, not a one-liner.
    if lower.matches(',').count() >= 2
        && (lower.contains(" and ") || lower.contains(" but ") || lower.contains(" because "))
    {
        score += 1;
    }

    // 9. Follow-up cues ("more", "continue", "elaborate on that", "go on")
    //    mean the user wants the PREVIOUS thread extended — high length.
    if lower.contains("more")
        || lower.contains("continue")
        || lower.contains("go on")
        || lower.contains("keep going")
        || lower.contains("elaborate")
        || lower.contains("tell me more")
        || lower.contains("and then")
    {
        score += 2;
    }

    if is_task_context {
        return category_plan("task_coding", is_mobile);
    }

    if deep_verb || score >= 7 {
        return category_plan("open_ended", is_mobile);
    }

    if SHALLOW_Q.iter().any(|v| lower.contains(v)) || lower.ends_with('?') || score >= 2 {
        return category_plan("factual", is_mobile);
    }

    // ── Map score → level ─────────────────────────────────────────────────
    let level: u8 = if score >= 9 {
        6 // deep explain / write
    } else if score >= 7 {
        5
    } else if score >= 5 {
        4
    } else if score >= 3 {
        3
    } else if score >= 2 {
        2
    } else {
        1 // short banter / simple question
    };

    level_plan(level, is_mobile)
}

#[cfg(test)]
mod tests {
    use super::plan_reply;

    #[test]
    fn plan_reply_budgets_scale_with_complexity() {
        let short = plan_reply("hi", false);
        assert_eq!(short.category, "greeting");
        assert!(short.max_tokens <= 48);

        let explain = plan_reply("explain how neural networks work", false);
        assert_eq!(explain.category, "open_ended");
        assert!(short.max_tokens >= 28); // sanity: mobile greeting is even smaller
        assert!(explain.max_tokens >= 96); // desktop first-pass; continuations add more

        let code = plan_reply("write a rust function to sort a list", false);
        assert_eq!(code.category, "task_coding");
        assert!(code.max_tokens >= 160); // desktop first-pass; continuations add more

        let mobile = plan_reply("explain how neural networks work", true);
        assert!(mobile.max_tokens < explain.max_tokens);
    }
}

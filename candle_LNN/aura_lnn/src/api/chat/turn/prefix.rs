use crate::api::chat::turn::extract_user_from_turn;

pub fn build_memory_prefix(memories: &[String]) -> Option<String> {
    let mut facts: Vec<String> = Vec::new();

    for m in memories {
        let lower = m.to_lowercase();
        if lower.starts_with("summary:") { continue; }
        if lower.contains("vision:") || lower.contains("objects=[")
            || lower.contains("screen_visible") || lower.contains("camera") { continue; }

        let content = if lower.starts_with("user's ") || lower.starts_with("user ") {
            convert_fact_to_second_person(m.trim())
        }
        else if lower.starts_with("user:") {
            let user_part = extract_user_from_turn(m);
            if user_part.is_empty() || user_part.to_lowercase().starts_with("aura:") { continue; }
            convert_first_to_second_person(&user_part)
        }
        else {
            if lower.starts_with("aura:") || lower.starts_with("assistant:") { continue; }
            convert_first_to_second_person(m.trim())
        };

        if content.is_empty() { continue; }

        let c = if content.chars().count() > 80 {
            content.chars().take(80).collect::<String>().trim().to_string()
        } else { content.trim().to_string() };

        if !facts.iter().any(|f| f == &c) {
            facts.push(c);
        }
        if facts.len() >= 8 { break; }
    }

    if facts.is_empty() { return None; }
    let joined = facts.join(", ");
    let joined = if joined.chars().count() > 200 {
        joined.chars().take(200).collect()
    } else { joined };
    Some(format!("[MEMORY: {joined}]\n"))
}

/// Build a compact conversation recap from recent turns so the model has
/// multi-turn context even after a KV-cache reset.
///
/// The recurrent model carries conversation state in its KV cache, but when
/// n_past hits the watermark (2304/3072), the cache is cleared and only the
/// system prompt is re-warmed — all conversation history is lost. This recap
/// is included in the generation prompt so the model always sees the last few
/// turns as text, regardless of cache resets.
///
/// Format: `[Recent chat:\nUser: X\nAURA: Y\nUser: Z\nAURA: W\n]`
/// Each turn is capped to ~100 chars so the recap stays compact.
pub fn build_conversation_recap(memories: &[String]) -> Option<String> {
    let mut turns: Vec<(String, String)> = Vec::new(); // (speaker, content)

    for m in memories {
        let lower = m.to_lowercase();
        if lower.starts_with("user:") {
            let content = extract_user_from_turn(m);
            if !content.is_empty() {
                let clipped: String = content.chars().take(100).collect();
                turns.push(("User".to_string(), clipped.trim().to_string()));
            }
        } else if lower.starts_with("aura:") || lower.starts_with("assistant:") {
            let content = if lower.starts_with("aura:") {
                m[5..].trim().to_string()
            } else {
                m[10..].trim().to_string()
            };
            if !content.is_empty() {
                let clipped: String = content.chars().take(100).collect();
                turns.push(("AURA".to_string(), clipped.trim().to_string()));
            }
        }
    }

    if turns.is_empty() {
        return None;
    }

    // Keep only the last 6 turns (3 user/assistant pairs) for compactness.
    let start = turns.len().saturating_sub(6);
    let recent = &turns[start..];

    let mut lines = Vec::new();
    for (speaker, content) in recent {
        lines.push(format!("{speaker}: {content}"));
    }

    Some(format!("[Recent chat:\n{}\n]\n", lines.join("\n")))
}

fn convert_fact_to_second_person(fact: &str) -> String {
    let lower = fact.to_lowercase();
    if lower.starts_with("user's ") {
        let rest = &fact[7..];
        format!("your {}", rest)
    } else if lower.starts_with("user ") {
        let rest = &fact[5..];
        let rest = rest
            .replacen("likes ", "like ", 1)
            .replacen("loves ", "love ", 1)
            .replacen("enjoys ", "enjoy ", 1)
            .replacen("prefers ", "prefer ", 1)
            .replacen("hates ", "hate ", 1)
            .replacen("lives in ", "live in ", 1)
            .replacen("is from ", "are from ", 1)
            .replacen("studies ", "study ", 1)
            .replacen("works as ", "work as ", 1)
            .replacen("works at ", "work at ", 1)
            .replacen("is a ", "are a ", 1)
            .replacen("is an ", "are an ", 1)
            .replacen("is feeling ", "are feeling ", 1)
            .replacen("is learning ", "are learning ", 1)
            .replacen("is reading ", "are reading ", 1)
            .replacen("is allergic to ", "are allergic to ", 1)
            .replacen("is vegan", "are vegan", 1)
            .replacen("is vegetarian", "are vegetarian", 1)
            .replacen("has a ", "have a ", 1)
            .replacen("has an ", "have an ", 1)
            .replacen("has ", "have ", 1)
            .replacen("wants to ", "want to ", 1)
            .replacen("teaches ", "teach ", 1);
        format!("you {}", rest)
    } else {
        convert_first_to_second_person(fact)
    }
}

pub(crate) fn format_memory_appendage(memories: &[String]) -> Option<String> {
    format_memory_appendage_for_query("", memories)
}

/// Build a query-specific "I remember: ..." tail for the recall fast-path.
///
/// The old `format_memory_appendage` had two critical bugs:
///  1. It EXCLUDED name facts (`if lower.starts_with("user's name is") { return false; }`),
///     so "what is my name" could never return the name — it returned an
///     irrelevant semantic hit instead ("I remember: whats a good book recommendation").
///  2. It took `good.first()` — the first semantic RAG hit — which was often
///     an unrelated conversation turn, not the fact the user asked about.
///
/// This version inspects the query to pick the RIGHT fact category:
///  "what is my name" → name fact
///  "how old am i"    → age fact
///  "where do i live" → location fact
///  "what is my cat's name" → pet fact
///  etc.
pub(crate) fn format_memory_appendage_for_query(
    query: &str,
    memories: &[String],
) -> Option<String> {
    if memories.is_empty() {
        return None;
    }

    let q = query.to_lowercase();

    // ── Query-specific fact matching ──────────────────────────────────
    // For each recall query type, find the matching fact category.
    // This replaces the old "take first semantic hit" which returned
    // irrelevant memories.

    // Name queries: "what is my name", "who am i", "do you remember my name"
    if q.contains("my name") || q.contains("who am i") || q.contains("do you know my name") {
        for m in memories {
            let lower = m.to_lowercase();
            if lower.starts_with("user's name is ") {
                let name = m[16..].trim();
                if !name.is_empty() {
                    return Some(format!(" Your name is {}.", name));
                }
            }
            if lower.starts_with("user ") && lower.contains("name is") {
                if let Some(idx) = lower.find("name is") {
                    let name = m[idx + 7..].trim();
                    if !name.is_empty() {
                        return Some(format!(" Your name is {}.", name));
                    }
                }
            }
        }
    }

    // Age queries: "how old am i", "what is my age"
    if q.contains("how old") || q.contains("my age") {
        for m in memories {
            let lower = m.to_lowercase();
            if lower.starts_with("user's age is ") {
                let age = m[14..].trim();
                if !age.is_empty() {
                    return Some(format!(" You are {} years old.", age));
                }
            }
        }
    }

    // Location queries: "where do i live", "where am i"
    if q.contains("where do i live") || q.contains("where am i") || q.contains("where's my") {
        for m in memories {
            let lower = m.to_lowercase();
            if lower.starts_with("user lives in ") {
                let loc = m[14..].trim();
                if !loc.is_empty() {
                    return Some(format!(" You live in {}.", loc));
                }
            }
            if lower.starts_with("user is based in ") {
                let loc = m[17..].trim();
                if !loc.is_empty() {
                    return Some(format!(" You're based in {}.", loc));
                }
            }
        }
    }

    // Pet queries: "what is my cat's name", "do i have a pet"
    if q.contains("cat") || q.contains("dog") || q.contains("pet") {
        for m in memories {
            let lower = m.to_lowercase();
            if lower.starts_with("user has a cat named ") {
                let name = m[21..].trim();
                if !name.is_empty() {
                    return Some(format!(" Your cat's name is {}.", name));
                }
            }
            if lower.starts_with("user has a dog named ") {
                let name = m[21..].trim();
                if !name.is_empty() {
                    return Some(format!(" Your dog's name is {}.", name));
                }
            }
            if lower.contains("has a ") && lower.contains("named ") {
                // Generic pet/animal fact
                let content = convert_fact_to_second_person(m.trim());
                if !content.is_empty() {
                    return Some(format!(" {}.", content));
                }
            }
        }
    }

    // Preference queries: "do i prefer", "do i like", "what do i like"
    if q.contains("prefer") || q.contains("do i like") || q.contains("favorite") {
        for m in memories {
            let lower = m.to_lowercase();
            if lower.starts_with("user prefers ") {
                let pref = m[13..].trim();
                if !pref.is_empty() {
                    return Some(format!(" You prefer {}.", pref));
                }
            }
            if lower.starts_with("user likes ") {
                let pref = m[11..].trim();
                if !pref.is_empty() {
                    return Some(format!(" You like {}.", pref));
                }
            }
            if lower.starts_with("user's favorite ") || lower.starts_with("user's favourite ") {
                let content = convert_fact_to_second_person(m.trim());
                if !content.is_empty() {
                    return Some(format!(" {}.", content));
                }
            }
        }
    }

    // Work/occupation queries: "where do i work", "what do i do"
    if q.contains("where do i work") || q.contains("what do i do") || q.contains("my job") {
        for m in memories {
            let lower = m.to_lowercase();
            if lower.starts_with("user works at ") || lower.starts_with("user works as ")
                || lower.starts_with("user runs ")
            {
                let content = convert_fact_to_second_person(m.trim());
                if !content.is_empty() {
                    return Some(format!(" {}.", content));
                }
            }
        }
    }

    // Language/learning queries: "what language am i learning"
    if q.contains("language") || q.contains("learning") {
        for m in memories {
            let lower = m.to_lowercase();
            if lower.starts_with("user is learning ") || lower.starts_with("user studies ") {
                let content = convert_fact_to_second_person(m.trim());
                if !content.is_empty() {
                    return Some(format!(" {}.", content));
                }
            }
        }
    }

    // "list everything you know about me" — list ALL facts
    if q.contains("list everything") || q.contains("what have i told you")
        || q.contains("what do you know about me")
    {
        let mut facts_list: Vec<String> = Vec::new();
        for m in memories {
            let lower = m.to_lowercase();
            if lower.starts_with("summary:") || lower.starts_with("vision:") {
                continue;
            }
            if lower.starts_with("user:") || lower.starts_with("aura:") {
                continue;
            }
            let content = if lower.starts_with("user's ") || lower.starts_with("user ") {
                convert_fact_to_second_person(m.trim())
            } else {
                m.trim().to_string()
            };
            if !content.is_empty() && !facts_list.contains(&content) {
                facts_list.push(content);
            }
        }
        if !facts_list.is_empty() {
            return Some(format!(" Here's what I know: {}.", facts_list.join("; ")));
        }
    }

    // ── Generic fallback: pick the most relevant fact ─────────────────
    // Only used when the query didn't match a specific category above.
    // Unlike the old code, we do NOT exclude name facts — they're the most
    // important identity fact and should be returned when relevant.
    let good: Vec<&String> = memories.iter()
        .filter(|m| {
            let lower = m.to_lowercase();
            if lower.starts_with("summary:") { return false; }
            if lower.starts_with("vision:") || lower.contains("objects=[") { return false; }
            if lower.starts_with("user:") || lower.starts_with("aura:") { return false; }
            let reject = ["feeling", "bored", "doing for fun"];
            for r in &reject {
                if lower.contains(r) { return false; }
            }
            true
        })
        .collect();

    if good.is_empty() {
        return None;
    }

    let hit = good.first()?;
    let lower = hit.to_lowercase();
    let content = if lower.starts_with("user's ") || lower.starts_with("user ") {
        convert_fact_to_second_person(hit.trim())
    } else {
        hit.trim().to_string()
    };
    if content.is_empty() {
        return None;
    }
    let has_latin = content.chars().any(|c| c.is_ascii_alphabetic());
    let has_non_latin = content.chars().any(|c| c.is_alphabetic() && !c.is_ascii());
    if !has_latin && has_non_latin {
        return None;
    }
    Some(format!(" I remember: {}.", content))
}

fn convert_first_to_second_person(text: &str) -> String {
    let mut r = text.to_string();
    r = r.replace("i'm ", "you're ").replace("I'm ", "you're ");
    r = r.replace("i am ", "you are ").replace("I am ", "you are ");
    r = r.replace("my ", "your ").replace("My ", "your ");
    r = r.replace("i like", "you like").replace("I like", "you like");
    r = r.replace("i love", "you love").replace("I love", "you love");
    r = r.replace("i live", "you live").replace("I live", "you live");
    r = r.replace("i enjoy", "you enjoy").replace("I enjoy", "you enjoy");
    r = r.replace("i have", "you have").replace("I have", "you have");
    r = r.replace("mine", "yours").replace("myself", "yourself");
    r = replace_standalone_word(&r, "i", "you");
    r = replace_standalone_word(&r, "I", "you");
    r = replace_standalone_word(&r, "me", "you");
    r
}

fn replace_standalone_word(text: &str, word: &str, replacement: &str) -> String {
    let wb = word.as_bytes(); let rb = replacement.as_bytes();
    let bytes = text.as_bytes(); let n = bytes.len(); let wl = wb.len();
    let mut out = String::with_capacity(n);
    let mut i = 0;
    while i < n {
        if i + wl <= n && &bytes[i..i + wl] == wb
            && (i == 0 || !bytes[i - 1].is_ascii_alphanumeric())
            && (i + wl >= n || !bytes[i + wl].is_ascii_alphanumeric())
        {
            out.push_str(std::str::from_utf8(rb).unwrap_or(replacement));
            i += wl;
        } else { out.push(bytes[i] as char); i += 1; }
    }
    out
}

pub fn build_recall_prefill(prompt: &str, memories: &[String]) -> Option<String> {
    let lower = prompt.to_lowercase();
    let is_name_query = lower.contains("what is my name") || lower.contains("what's my name")
        || lower.contains("who am i") || lower.contains("do you remember my name")
        || lower.contains("do you know my name");
    if !is_name_query { return None; }

    for m in memories {
        let m_lower = m.to_lowercase();
        if m_lower.starts_with("user's name is") {
            let name = m[14..].trim();
            if !name.is_empty() {
                return Some(format!("Your name is {}.", name));
            }
        }
        if m_lower.starts_with("user ") && m_lower.contains("name is") {
            if let Some(idx) = m_lower.find("name is") {
                let name = m[idx + 7..].trim();
                if !name.is_empty() {
                    return Some(format!("Your name is {}.", name));
                }
            }
        }
    }
    None
}

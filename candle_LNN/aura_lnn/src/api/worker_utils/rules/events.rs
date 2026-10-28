// rules/events.rs — Birthday, schedule, reminders, life events
use super::is_valid_fact;

pub fn extract(cleaned: &str, original: &str) -> Vec<String> {
    let mut facts = Vec::new();

    // Birthday: "my birthday is X", "my birthday's on X", "i was born on X"
    let anchors = [
        "my birthday is ",
        "my birthday's on ",
        "my birthday is on ",
        "i was born on ",
    ];
    for anchor in &anchors {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?']).unwrap_or(rest.len());
            let date = rest[..end].trim();
            if date.len() >= 3 && date.chars().any(|c| c.is_alphanumeric()) {
                let orig = restore_case(date, original);
                let f = format!("User's birthday is {}", orig);
                if is_valid_fact(&f) {
                    facts.push(f);
                }
            }
            break;
        }
    }

    // ── Life events: exams, deadlines, interviews, presentations, flights ──
    let event_patterns: &[(&str, &str)] = &[
        // Exams
        ("my exam is ", "User has an exam on "),
        ("my exam is on ", "User has an exam on "),
        ("my final exam is ", "User has an exam on "),
        ("my final exam is on ", "User has an exam on "),
        ("i have an exam ", "User has an exam "),
        ("i have a final exam ", "User has an exam "),
        ("i have my exam ", "User has an exam "),
        ("exam on ", "User has an exam on "),
        ("exam next ", "User has an exam next "),
        ("exam tomorrow", "User has an exam tomorrow"),
        ("exam today", "User has an exam today"),
        // Deadlines
        ("my deadline is ", "User has a deadline on "),
        ("my deadline is in ", "User has a deadline in "),
        ("deadline is in ", "User has a deadline in "),
        ("deadline in ", "User has a deadline in "),
        ("deadline is ", "User has a deadline on "),
        ("thesis deadline is ", "User has a thesis deadline on "),
        ("thesis deadline is in ", "User has a thesis deadline in "),
        // Interviews
        ("my interview is ", "User has an interview on "),
        ("my interview is on ", "User has an interview on "),
        ("i have an interview ", "User has an interview "),
        ("i have a job interview ", "User has a job interview "),
        ("interview next week", "User has an interview next week"),
        ("interview next ", "User has an interview next "),
        // Presentations
        ("my presentation is ", "User has a presentation on "),
        (
            "my presentation is tomorrow",
            "User has a presentation tomorrow",
        ),
        ("i have a presentation ", "User has a presentation "),
        ("presentation tomorrow", "User has a presentation tomorrow"),
        ("presentation at ", "User has a presentation at "),
        // Weddings
        ("my friend's wedding is ", "User has a wedding on "),
        ("my friends wedding is ", "User has a wedding on "),
        ("wedding is on ", "User has a wedding on "),
        ("wedding is ", "User has a wedding on "),
        ("wedding on ", "User has a wedding on "),
        // Flights
        ("my flight is on ", "User has a flight on "),
        ("my flight to ", "User has a flight to "),
        ("flight on ", "User has a flight on "),
        // Appointments
        ("my appointment is at ", "User has an appointment at "),
        ("my appointment is on ", "User has an appointment on "),
        (
            "i have a dentist appointment ",
            "User has a dentist appointment ",
        ),
        (
            "i have a doctor appointment ",
            "User has a doctor appointment ",
        ),
        // Meetings
        ("my meeting is at ", "User has a meeting at "),
        ("my meeting is on ", "User has a meeting on "),
        ("i have a meeting ", "User has a meeting "),
    ];

    for (anchor, fact_prefix) in event_patterns {
        if let Some(idx) = cleaned.find(anchor) {
            let rest = &cleaned[idx + anchor.len()..];
            let end = rest.find(['.', '!', '?', ',']).unwrap_or(rest.len());
            let detail = rest[..end].trim();
            // Cut at " and " / " but " / " so " / " i'm " to avoid grabbing extra clauses
            let detail = detail
                .strip_prefix("and ")
                .or_else(|| detail.strip_prefix("but "))
                .or_else(|| detail.strip_prefix("so "))
                .or_else(|| detail.strip_prefix("i'm "))
                .or_else(|| detail.strip_prefix("i am "))
                .or_else(|| detail.strip_prefix("i "))
                .unwrap_or(detail)
                .split(" and ")
                .next()
                .unwrap_or(detail)
                .split(" but ")
                .next()
                .unwrap_or(detail)
                .split(" so ")
                .next()
                .unwrap_or(detail)
                .trim();
            if detail.is_empty() {
                // No detail — just use the prefix (e.g. "User has an interview next week")
                let f = fact_prefix.to_string();
                if is_valid_fact(&f) {
                    facts.push(f);
                }
            } else if detail.chars().any(|c| c.is_alphanumeric()) && detail.len() >= 2 {
                let orig = restore_case(detail, original);
                let f = if fact_prefix.ends_with(' ') {
                    format!("{}{}", fact_prefix, orig)
                } else {
                    format!("{} {}", fact_prefix, orig)
                };
                if is_valid_fact(&f) {
                    facts.push(f);
                }
            }
            break; // one event per anchor group
        }
    }

    facts
}

fn restore_case(value_lower: &str, original: &str) -> String {
    let orig_lower = original.to_lowercase();
    if let Some(pos) = orig_lower.find(value_lower) {
        original[pos..pos + value_lower.len()].to_string()
    } else {
        value_lower
            .split_whitespace()
            .map(|w| {
                let mut c = w.chars();
                c.next().unwrap_or(' ').to_uppercase().collect::<String>() + c.as_str()
            })
            .collect::<Vec<_>>()
            .join(" ")
    }
}

pub fn cap_memory_item(s: &str, max_chars: usize) -> String {
    let s = s.trim();
    if s.chars().count() <= max_chars {
        return s.to_string();
    }
    let mut out: String = s.chars().take(max_chars).collect();
    if let Some(idx) = out.rfind(|c: char| c.is_whitespace()) {
        out.truncate(idx);
    }
    out.push('…');
    out
}

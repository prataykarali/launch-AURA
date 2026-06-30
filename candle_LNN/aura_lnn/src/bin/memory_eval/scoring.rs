use crate::FUZZY_THRESHOLD;

pub fn jaro_similarity(s1: &str, s2: &str) -> f64 {
    if s1 == s2 {
        return 1.0;
    }
    let s1_chars: Vec<char> = s1.chars().collect();
    let s2_chars: Vec<char> = s2.chars().collect();
    let len1 = s1_chars.len();
    let len2 = s2_chars.len();
    if len1 == 0 || len2 == 0 {
        return 0.0;
    }

    let match_distance = (len1.max(len2) / 2).saturating_sub(1);
    let mut s1_matches = vec![false; len1];
    let mut s2_matches = vec![false; len2];
    let mut matches = 0usize;
    let mut transpositions = 0usize;

    for i in 0..len1 {
        let start = i.saturating_sub(match_distance);
        let end = (i + match_distance + 1).min(len2);
        for j in start..end {
            if s2_matches[j] || s1_chars[i] != s2_chars[j] {
                continue;
            }
            s1_matches[i] = true;
            s2_matches[j] = true;
            matches += 1;
            break;
        }
    }
    if matches == 0 {
        return 0.0;
    }

    let mut k = 0;
    for i in 0..len1 {
        if !s1_matches[i] {
            continue;
        }
        while !s2_matches[k] {
            k += 1;
        }
        if s1_chars[i] != s2_chars[k] {
            transpositions += 1;
        }
        k += 1;
    }

    let m = matches as f64;
    (m / len1 as f64 + m / len2 as f64 + (m - transpositions as f64 / 2.0) / m) / 3.0
}

pub fn jaro_winkler(s1: &str, s2: &str) -> f64 {
    let jaro = jaro_similarity(s1, s2);
    let prefix_len = s1
        .chars()
        .zip(s2.chars())
        .take(4)
        .take_while(|(a, b)| a == b)
        .count();
    jaro + prefix_len as f64 * 0.1 * (1.0 - jaro)
}

pub fn fuzzy_contains(response_words: &[&str], keyword: &str) -> bool {
    for word in response_words {
        if jaro_winkler(word, keyword) >= FUZZY_THRESHOLD {
            return true;
        }
    }
    for window in response_words.windows(2) {
        let bigram = format!("{} {}", window[0], window[1]);
        if jaro_winkler(&bigram, keyword) >= FUZZY_THRESHOLD {
            return true;
        }
    }
    for window in response_words.windows(3) {
        let trigram = format!("{} {} {}", window[0], window[1], window[2]);
        if jaro_winkler(&trigram, keyword) >= FUZZY_THRESHOLD {
            return true;
        }
    }
    false
}

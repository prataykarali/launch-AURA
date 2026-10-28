use std::fs;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use crate::{CaseStat, CategoryResult, MemoryTestStats, FUZZY_THRESHOLD};

fn timestamp() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    format!("unix:{secs}")
}

fn bucket(map: &mut std::collections::HashMap<String, (usize, usize)>, key: &str, passed: bool) {
    let e = map.entry(key.to_string()).or_insert((0, 0));
    e.1 += 1;
    if passed {
        e.0 += 1;
    }
}

fn to_cat_map(
    raw: &std::collections::HashMap<String, (usize, usize)>,
) -> std::collections::HashMap<String, CategoryResult> {
    let mut out = std::collections::HashMap::new();
    for (k, &(passed, total)) in raw {
        let accuracy = if total == 0 {
            0.0
        } else {
            (passed as f64 / total as f64) * 100.0
        };
        out.insert(
            k.clone(),
            CategoryResult {
                passed,
                total,
                accuracy,
            },
        );
    }
    out
}

pub fn print_results(
    cases_stats: &[CaseStat],
    suite_duration: &Duration,
) -> (
    usize,
    usize,
    f64,
    std::collections::HashMap<String, CategoryResult>,
    std::collections::HashMap<String, CategoryResult>,
) {
    let mut passed_count = 0;
    let mut failed_count = 0;
    let mut category_stats = std::collections::HashMap::<String, (usize, usize)>::new();
    let mut difficulty_stats = std::collections::HashMap::<String, (usize, usize)>::new();
    let mut failure_modes = std::collections::HashMap::<String, usize>::new();

    for stat in cases_stats {
        bucket(&mut category_stats, &stat.category, stat.passed);
        bucket(&mut difficulty_stats, &stat.difficulty, stat.passed);

        if stat.passed {
            passed_count += 1;
            println!(
                "Case #{:<3} [{:<20}] ({:<9}) -> PASSED (dur={}ms, generated: {} chars)",
                stat.id,
                stat.category,
                stat.difficulty,
                stat.duration_ms,
                stat.got.len()
            );
        } else {
            failed_count += 1;
            // Failure mode heuristics for paper writeup
            let lower = stat.got.to_lowercase();
            let mode = if lower.trim().is_empty() {
                "empty_response"
            } else if lower.contains("don't know")
                || lower.contains("dont know")
                || lower.contains("not sure")
                || lower.contains("no idea")
            {
                "amnesia_claim"
            } else if lower.contains("as an ai") || lower.contains("language model") {
                "persona_violation"
            } else if stat
                .expected
                .iter()
                .any(|k| lower.contains(&k.to_lowercase()))
            {
                "partial_keyword_miss"
            } else {
                "keyword_miss"
            };
            *failure_modes.entry(mode.to_string()).or_insert(0) += 1;

            println!(
                "Case #{:<3} [{:<20}] ({:<9}) -> FAILED [{mode}]\n  Query: {}\n  Expected: {:?}\n  Got: {}\n",
                stat.id,
                stat.category,
                stat.difficulty,
                stat.query,
                stat.expected,
                stat.got.trim()
            );
        }
    }

    println!("\n==================================================");
    println!(
        "Evaluation Completed in {:.2}s",
        suite_duration.as_secs_f64()
    );
    println!("Total Passed: {} / {}", passed_count, cases_stats.len());
    println!("Total Failed: {} / {}", failed_count, cases_stats.len());
    let accuracy = if cases_stats.is_empty() {
        0.0
    } else {
        (passed_count as f64 / cases_stats.len() as f64) * 100.0
    };
    println!("Accuracy:     {accuracy:.2}%");
    println!("==================================================");

    println!("Performance by Category:");
    let mut cats: Vec<_> = category_stats.iter().collect();
    cats.sort_by(|a, b| a.0.cmp(b.0));
    for (cat, &(passed, total)) in cats {
        let cat_accuracy = (passed as f64 / total as f64) * 100.0;
        println!("  {cat:<25}: {passed} / {total} ({cat_accuracy:.2}%)");
    }
    println!("==================================================");

    println!("Performance by Difficulty:");
    let mut diffs: Vec<_> = difficulty_stats.iter().collect();
    diffs.sort_by(|a, b| a.0.cmp(b.0));
    for (diff, &(passed, total)) in diffs {
        let d_acc = (passed as f64 / total as f64) * 100.0;
        println!("  {diff:<12}: {passed} / {total} ({d_acc:.2}%)");
    }
    println!("==================================================");

    println!("Failure Mode Analysis:");
    let mut modes: Vec<_> = failure_modes.iter().collect();
    modes.sort_by(|a, b| b.1.cmp(a.1));
    if modes.is_empty() {
        println!("  (none)");
    } else {
        for (mode, n) in modes {
            println!("  {mode:<22}: {n}");
        }
    }
    println!("==================================================");

    (
        passed_count,
        failed_count,
        accuracy,
        to_cat_map(&category_stats),
        to_cat_map(&difficulty_stats),
    )
}

pub fn write_json_stats(
    model_path: &str,
    cases_stats: Vec<CaseStat>,
    total_cases: usize,
    passed_count: usize,
    failed_count: usize,
    accuracy: f64,
    categories_map: std::collections::HashMap<String, CategoryResult>,
    difficulties_map: std::collections::HashMap<String, CategoryResult>,
    suite_duration: &Duration,
) {
    let stats_json = MemoryTestStats {
        date: timestamp(),
        model_path: model_path.to_string(),
        architecture: "prefix_injection".to_string(),
        total_cases,
        passed: passed_count,
        failed: failed_count,
        accuracy,
        suite_run_time_secs: suite_duration.as_secs_f64(),
        categories: categories_map,
        difficulties: difficulties_map,
        cases: cases_stats,
    };

    if let Ok(json_str) = serde_json::to_string_pretty(&stats_json) {
        let _ = fs::write(
            "/home/pratay-karali/launch-AURA/Mitacs/personal_memory_stats.json",
            &json_str,
        );
        let _ = fs::write(
            "/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs/personal_memory_stats_prefix.json",
            &json_str,
        );
    }
}

pub fn write_markdown_report(
    model_path: &str,
    cases_stats: &[CaseStat],
    total_cases: usize,
    passed_count: usize,
    failed_count: usize,
    accuracy: f64,
    suite_duration: &Duration,
) {
    // Rebuild difficulty + failure tables for the markdown report
    let mut difficulty_stats = std::collections::HashMap::<String, (usize, usize)>::new();
    let mut category_stats = std::collections::HashMap::<String, (usize, usize)>::new();
    let mut failure_modes = std::collections::HashMap::<String, usize>::new();
    for stat in cases_stats {
        bucket(&mut difficulty_stats, &stat.difficulty, stat.passed);
        bucket(&mut category_stats, &stat.category, stat.passed);
        if !stat.passed {
            let lower = stat.got.to_lowercase();
            let mode = if lower.trim().is_empty() {
                "empty_response"
            } else if lower.contains("don't know")
                || lower.contains("dont know")
                || lower.contains("not sure")
            {
                "amnesia_claim"
            } else if lower.contains("as an ai") || lower.contains("language model") {
                "persona_violation"
            } else if stat
                .expected
                .iter()
                .any(|k| lower.contains(&k.to_lowercase()))
            {
                "partial_keyword_miss"
            } else {
                "keyword_miss"
            };
            *failure_modes.entry(mode.to_string()).or_insert(0) += 1;
        }
    }

    let mut cat_lines = String::new();
    let mut cats: Vec<_> = category_stats.iter().collect();
    cats.sort_by(|a, b| a.0.cmp(b.0));
    for (cat, &(p, t)) in cats {
        cat_lines.push_str(&format!(
            "| {} | {}/{} | {:.1}% |\n",
            cat,
            p,
            t,
            100.0 * p as f64 / t as f64
        ));
    }

    let mut diff_lines = String::new();
    let mut diffs: Vec<_> = difficulty_stats.iter().collect();
    diffs.sort_by(|a, b| a.0.cmp(b.0));
    for (d, &(p, t)) in diffs {
        diff_lines.push_str(&format!(
            "| {} | {}/{} | {:.1}% |\n",
            d,
            p,
            t,
            100.0 * p as f64 / t as f64
        ));
    }

    let mut fail_lines = String::new();
    let mut modes: Vec<_> = failure_modes.iter().collect();
    modes.sort_by(|a, b| b.1.cmp(a.1));
    for (m, n) in modes {
        fail_lines.push_str(&format!("| {m} | {n} |\n"));
    }
    if fail_lines.is_empty() {
        fail_lines.push_str("| (none) | 0 |\n");
    }

    let report_content = format!(
        "# AURA Personal AI Memory Evaluation Report (PREFIX INJECTION)\n\n\
        - Date: {}\n\
        - Model: `{model_path}`\n\
        - Architecture: **prefix injection** (`[MEMORY: ...]` before user query)\n\
        - Dataset: personal_memory_dataset.json (1000 cases / 10 categories)\n\
        - Total Cases: {total_cases}\n\
        - Passed: {passed_count}\n\
        - Failed: {failed_count}\n\
        - **Overall Accuracy: {accuracy:.2}%**\n\
        - Suite Run Time: {:.2}s\n\
        - Matching: Jaro-Winkler fuzzy (threshold={FUZZY_THRESHOLD:.2})\n\
        - NOTE: Previous 83.4% figure was measured under **appendage** architecture and is obsolete.\n\n\
        ## Per-Category Breakdown\n\n\
        | Category | Passed | Accuracy |\n\
        |----------|--------|----------|\n\
        {cat_lines}\n\
        ## Per-Difficulty Breakdown\n\n\
        | Difficulty | Passed | Accuracy |\n\
        |------------|--------|----------|\n\
        {diff_lines}\n\
        ## Failure Mode Analysis\n\n\
        | Mode | Count |\n\
        |------|------:|\n\
        {fail_lines}\n",
        timestamp(),
        suite_duration.as_secs_f64(),
    );
    let _ = fs::write(
        "/home/pratay-karali/launch-AURA/Mitacs/personal_memory_report.md",
        &report_content,
    );
    let _ = fs::write(
        "/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs/personal_memory_report_prefix.md",
        &report_content,
    );
}

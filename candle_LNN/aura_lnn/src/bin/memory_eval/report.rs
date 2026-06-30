use std::fs;
use std::time::Duration;

use crate::{CaseStat, CategoryResult, MemoryTestStats, FUZZY_THRESHOLD};

pub fn print_results(
    cases_stats: &[CaseStat],
    suite_duration: &Duration,
) -> (
    usize,
    usize,
    f64,
    std::collections::HashMap<String, CategoryResult>,
) {
    let mut passed_count = 0;
    let mut failed_count = 0;
    let mut category_stats = std::collections::HashMap::<String, (usize, usize)>::new();

    for stat in cases_stats {
        let stats = category_stats
            .entry(stat.category.clone())
            .or_insert((0, 0));
        stats.1 += 1;

        if stat.passed {
            passed_count += 1;
            stats.0 += 1;
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
            println!(
                "Case #{:<3} [{:<20}] ({:<9}) -> FAILED\n  Query: {}\n  Expected: {:?}\n  Got: {}\n",
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
    let accuracy = (passed_count as f64 / cases_stats.len() as f64) * 100.0;
    println!("Accuracy:     {accuracy:.2}%");
    println!("==================================================");

    println!("Performance by Category:");
    let mut categories_map = std::collections::HashMap::new();
    for (cat, &(passed, total)) in &category_stats {
        let cat_accuracy = (passed as f64 / total as f64) * 100.0;
        println!("  {cat:<25}: {passed} / {total} ({cat_accuracy:.2}%)");
        categories_map.insert(
            cat.clone(),
            CategoryResult {
                passed,
                total,
                accuracy: cat_accuracy,
            },
        );
    }
    println!("==================================================");

    (passed_count, failed_count, accuracy, categories_map)
}

pub fn write_json_stats(
    cases_stats: Vec<CaseStat>,
    total_cases: usize,
    passed_count: usize,
    failed_count: usize,
    accuracy: f64,
    categories_map: std::collections::HashMap<String, CategoryResult>,
    suite_duration: &Duration,
) {
    let stats_json = MemoryTestStats {
        date: chrono::Local::now().format("%Y-%m-%d %H:%M:%S").to_string(),
        total_cases,
        passed: passed_count,
        failed: failed_count,
        accuracy,
        suite_run_time_secs: suite_duration.as_secs_f64(),
        categories: categories_map,
        cases: cases_stats,
    };

    if let Ok(json_str) = serde_json::to_string_pretty(&stats_json) {
        let _ = fs::write(
            "/home/pratay-karali/launch-AURA/Mitacs/personal_memory_stats.json",
            json_str,
        );
    }
}

pub fn write_markdown_report(
    total_cases: usize,
    passed_count: usize,
    failed_count: usize,
    accuracy: f64,
    suite_duration: &Duration,
) {
    let report_content = format!(
        "# AURA Personal AI Memory Evaluation Report\n\n\
        - Date: {}\n\
        - Dataset: personal_memory_dataset.json (Evaluation subset)\n\
        - Total Cases: {}\n\
        - Passed: {}\n\
        - Failed: {}\n\
        - Accuracy: {:.2}%\n\
        - Suite Run Time: {:.2}s\n\
        - Matching: Jaro-Winkler fuzzy (threshold={:.2})\n\
        - Optimizations: XML Profile Isolation + Assistant Pre-filling\n",
        chrono::Local::now().format("%Y-%m-%d %H:%M:%S"),
        total_cases,
        passed_count,
        failed_count,
        accuracy,
        suite_duration.as_secs_f64(),
        FUZZY_THRESHOLD,
    );
    let _ = fs::write(
        "/home/pratay-karali/launch-AURA/Mitacs/personal_memory_report.md",
        report_content,
    );
}

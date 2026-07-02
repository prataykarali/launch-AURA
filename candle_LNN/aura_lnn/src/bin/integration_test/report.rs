use std::fs;
use std::collections::HashMap;
use super::types::TestResult;

pub fn print_final_report(results: &[TestResult]) {
    let total = results.len();
    let passed = results.iter().filter(|r| r.passed).count();
    let failed = total - passed;
    let accuracy = (passed as f64 / total as f64) * 100.0;

    println!("\n{}", "=".repeat(80));
    println!("  FINAL REPORT — AURA Brutal Integration Test Suite");
    println!("{}", "=".repeat(80));
    println!("\nTotal: {} | Passed: {} | Failed: {} | Accuracy: {:.1}%\n", total, passed, failed, accuracy);

    let suites: HashMap<String, Vec<&TestResult>> = results.iter().fold(HashMap::new(), |mut a, r| { a.entry(r.suite.clone()).or_default().push(r); a });
    let mut sn: Vec<String> = suites.keys().cloned().collect();
    sn.sort();
    for s in &sn {
        let c = suites.get(s).unwrap();
        let p = c.iter().filter(|r| r.passed).count();
        let t = c.len();
        println!("  [{}] {}/{} ({:.1}%)", s.to_uppercase(), p, t, (p as f64 / t as f64) * 100.0);
    }

    println!("  By Category:");
    let cats: HashMap<String, Vec<&TestResult>> = results.iter().fold(HashMap::new(), |mut a, r| { a.entry(r.category.clone()).or_default().push(r); a });
    let mut cn: Vec<String> = cats.keys().cloned().collect();
    cn.sort();
    for c in &cn {
        let cases = cats.get(c).unwrap();
        let p = cases.iter().filter(|r| r.passed).count();
        let t = cases.len();
        println!("    {:<25} {}/{} ({:.1}%)", c, p, t, (p as f64 / t as f64) * 100.0);
    }
    println!();

    let failures: Vec<&TestResult> = results.iter().filter(|r| !r.passed).collect();
    if !failures.is_empty() {
        println!("  FAILURES ({}):", failures.len());
        println!("  {}", "-".repeat(76));
        for f in &failures {
            println!("  [{}] #{} ({}/{}) {}", f.suite, f.id, f.category, f.difficulty, f.description);
            println!("         {}", f.detail);
        }
    }
    println!("\n{}", "=".repeat(80));
}

pub fn write_report_file(results: &[TestResult]) {
    let total = results.len();
    let passed = results.iter().filter(|r| r.passed).count();
    let failed = total - passed;
    let accuracy = (passed as f64 / total as f64) * 100.0;

    let mut report = String::new();
    report.push_str("# AURA Brutal Integration Test Report\n\n");
    report.push_str(&format!("- Date: {}\n", chrono::Local::now().format("%Y-%m-%d %H:%M:%S")));
    report.push_str(&format!("- Total: {} | Passed: {} | Failed: {} | Accuracy: {:.1}%\n\n", total, passed, failed, accuracy));

    report.push_str("| ID | Suite | Category | Difficulty | Passed | Description |\n");
    report.push_str("|----|-------|----------|------------|--------|-------------|\n");
    for r in results {
        let st = if r.passed { "PASS" } else { "FAIL" };
        report.push_str(&format!("| {} | {} | {} | {} | {} | {} |\n", r.id, r.suite, r.category, r.difficulty, st, r.description.replace('|', "/")));
    }

    report.push_str("\n## Failures\n\n");
    for r in results.iter().filter(|r| !r.passed) {
        report.push_str(&format!("- **#{} {}**: {} — {}\n", r.id, r.category, r.description, r.detail));
    }

    let path = "/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs/brutal_test_report.md";
    let _ = fs::write(path, &report);
    println!("Report: {}", path);

    let stats = serde_json::json!({
        "date": chrono::Local::now().to_rfc3339(),
        "total": total, "passed": passed, "failed": failed, "accuracy": accuracy,
        "cases": results.iter().map(|r| serde_json::json!({
            "id": r.id, "suite": r.suite, "category": r.category,
            "difficulty": r.difficulty, "passed": r.passed,
            "description": r.description, "detail": r.detail,
        })).collect::<Vec<_>>(),
    });
    let jpath = "/home/pratay-karali/launch-AURA/Mitacs/research/benchmark_logs/brutal_test_stats.json";
    let _ = fs::write(jpath, serde_json::to_string_pretty(&stats).unwrap());
    println!("Stats: {}", jpath);
}

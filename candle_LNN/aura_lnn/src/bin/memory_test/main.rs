use rayon::prelude::*;
use std::cell::RefCell;
use std::fs;
use std::path::Path;
use std::time::Instant;

use aura_lnn::api::configure_rayon_threads;
use aura_lnn::llama_engine::LlamaEngine;
use aura_lnn::memory::store::MemoryStore;

mod fuzzy;
mod report;
mod runner;
mod utils;

#[derive(serde::Deserialize, Debug)]
pub(crate) struct Turn {
    speaker: String,
    content: String,
}

#[derive(serde::Deserialize, Debug)]
pub(crate) struct Verification {
    query: String,
    expected_keywords: Vec<String>,
    negative_keywords: Vec<String>,
}

#[derive(serde::Deserialize, Debug)]
pub(crate) struct TestCase {
    id: usize,
    difficulty: String,
    category: String,
    turns: Vec<Turn>,
    verification: Verification,
}

#[derive(serde::Serialize, Clone)]
pub(crate) struct CaseStat {
    id: usize,
    category: String,
    difficulty: String,
    passed: bool,
    query: String,
    expected: Vec<String>,
    got: String,
    duration_ms: u64,
}

#[derive(serde::Serialize)]
pub(crate) struct CategoryResult {
    passed: usize,
    total: usize,
    accuracy: f64,
}

#[derive(serde::Serialize)]
pub(crate) struct MemoryTestStats {
    date: String,
    total_cases: usize,
    passed: usize,
    failed: usize,
    accuracy: f64,
    suite_run_time_secs: f64,
    categories: std::collections::HashMap<String, CategoryResult>,
    cases: Vec<CaseStat>,
}

const MODEL_PATH: &str = "../../aura_notebook/assets/LFM2.5-1.2B-Instruct-Q4_K_M.gguf";
pub(crate) const FUZZY_THRESHOLD: f64 = 0.82;

thread_local! {
    static THREAD_ENGINE: RefCell<LlamaEngine> = {
        let embedder = LlamaEngine::load_sibling_embedder(MODEL_PATH)
            .unwrap_or_else(|e| panic!("Error: bge embedder not found next to model: {e:?}"));
        let engine = LlamaEngine::new(
            MODEL_PATH,
            aura_lnn::device_backend::DeviceBackend::Cpu, // CPU backend for Android / mobile compatibility
            2048,
            2, // 2 inference threads per context to avoid context-switching overhead
            embedder,
        ).unwrap_or_else(|e| panic!("Failed to initialize LLM engine: {e:?}"));
        RefCell::new(engine)
    };
}

fn main() {
    std::env::set_var("AURA_NOTEBOOK_PATH", "/dev/null");
    configure_rayon_threads();

    println!("==================================================");
    println!("AURA Personal AI Memory Evaluation Suite (1000 cases)");
    println!("==================================================");

    let dataset_path = "/home/pratay-karali/launch-AURA/Mitacs/personal_memory_dataset.json";
    let dataset_content = fs::read_to_string(dataset_path)
        .unwrap_or_else(|e| panic!("Failed to read {dataset_path}: {e}"));

    let mut test_cases: Vec<TestCase> = serde_json::from_str(&dataset_content)
        .unwrap_or_else(|e| panic!("Failed to parse test cases: {e}"));

    if let Ok(limit_str) = std::env::var("AURA_TEST_LIMIT") {
        if let Ok(limit) = limit_str.parse::<usize>() {
            println!("Limiting run to first {limit} test cases.");
            test_cases.truncate(limit);
        }
    }

    println!("Successfully loaded {} test cases.", test_cases.len());
    println!("Running evaluation in parallel on CPU...");

    let start_suite = Instant::now();

    // Run all test cases in parallel using Rayon
    let cases_stats: Vec<CaseStat> = test_cases
        .par_iter()
        .map(|case| {
            // Thread-specific database file to prevent locks and connection pool mismatch in memory
            let thread_idx = rayon::current_thread_index().unwrap_or(0);
            let db_path = format!("temp_test_memory_{thread_idx}.db");

            if Path::new(&db_path).exists() {
                let _ = fs::remove_file(&db_path);
            }
            let store = MemoryStore::open(&db_path).expect("Failed to open test database");

            let res = THREAD_ENGINE.with(|engine_ref| {
                let mut engine = engine_ref.borrow_mut();
                runner::evaluate_case(case, &mut engine, &store)
            });

            // Clean up DB file
            drop(store);
            if Path::new(&db_path).exists() {
                let _ = fs::remove_file(&db_path);
                let _ = fs::remove_file(format!("{db_path}-shm"));
                let _ = fs::remove_file(format!("{db_path}-wal"));
            }

            res
        })
        .collect();

    let suite_duration = start_suite.elapsed();

    report::report_results(&cases_stats, test_cases.len(), suite_duration);
}

use rayon::prelude::*;
use std::cell::RefCell;
use std::fs;
use std::path::Path;
use std::sync::OnceLock;
use std::time::Instant;

use aura_lnn::api::configure_rayon_threads;
use aura_lnn::llama_engine::LlamaEngine;
use aura_lnn::memory::store::MemoryStore;

mod eval;
mod report;
mod scoring;
mod text;

#[derive(serde::Deserialize, Debug)]
struct Turn {
    speaker: String,
    content: String,
}

#[derive(serde::Deserialize, Debug)]
struct Verification {
    query: String,
    expected_keywords: Vec<String>,
    negative_keywords: Vec<String>,
}

#[derive(serde::Deserialize, Debug)]
struct TestCase {
    id: usize,
    difficulty: String,
    category: String,
    turns: Vec<Turn>,
    verification: Verification,
}

#[derive(serde::Serialize, Clone)]
struct CaseStat {
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
struct CategoryResult {
    passed: usize,
    total: usize,
    accuracy: f64,
}

#[derive(serde::Serialize)]
struct MemoryTestStats {
    date: String,
    model_path: String,
    architecture: String,
    total_cases: usize,
    passed: usize,
    failed: usize,
    accuracy: f64,
    suite_run_time_secs: f64,
    categories: std::collections::HashMap<String, CategoryResult>,
    difficulties: std::collections::HashMap<String, CategoryResult>,
    cases: Vec<CaseStat>,
}

pub const FUZZY_THRESHOLD: f64 = 0.82;

fn model_path() -> &'static str {
    static P: OnceLock<String> = OnceLock::new();
    P.get_or_init(|| {
        std::env::var("AURA_MODEL_PATH").unwrap_or_else(|_| {
            "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/LFM2.5-1.2B-Instruct-Q4_K_M.gguf"
                .to_string()
        })
    })
    .as_str()
}

fn dataset_path() -> String {
    std::env::var("AURA_DATASET_PATH").unwrap_or_else(|_| {
        "/home/pratay-karali/launch-AURA/Mitacs/research/test_suites/personal_memory_dataset.json"
            .to_string()
    })
}

thread_local! {
    static THREAD_ENGINE: RefCell<LlamaEngine> = {
        let path = model_path();
        let embedder = LlamaEngine::load_sibling_embedder(path)
            .unwrap_or_else(|e| panic!("Error: bge embedder not found for {path}: {e:?}"));
        let engine = LlamaEngine::new(
            path,
            aura_lnn::device_backend::DeviceBackend::Cpu,
            2048,
            2,
            embedder,
        )
        .unwrap_or_else(|e| panic!("Failed to initialize LLM engine for {path}: {e:?}"));
        RefCell::new(engine)
    };
}

fn main() {
    std::env::set_var("AURA_NOTEBOOK_PATH", "/dev/null");
    // Prefer serial-ish eval under low RAM: default 2 rayon threads so we don't
    // load N copies of a 700MB GGUF. Override with RAYON_NUM_THREADS.
    if std::env::var("RAYON_NUM_THREADS").is_err() {
        std::env::set_var("RAYON_NUM_THREADS", "2");
    }
    configure_rayon_threads();

    let model = model_path();
    let ds = dataset_path();
    println!("==================================================");
    println!("AURA Personal AI Memory Evaluation Suite");
    println!("Architecture: PREFIX INJECTION ([MEMORY:] before query)");
    println!("Model: {model}");
    println!("Dataset: {ds}");
    println!("Fuzzy threshold (Jaro-Winkler): {FUZZY_THRESHOLD}");
    println!("==================================================");

    let dataset_content =
        fs::read_to_string(&ds).unwrap_or_else(|e| panic!("Failed to read {ds}: {e}"));

    let mut test_cases: Vec<TestCase> = serde_json::from_str(&dataset_content)
        .unwrap_or_else(|e| panic!("Failed to parse test cases: {e}"));

    let limit = std::env::var("AURA_TEST_LIMIT")
        .ok()
        .and_then(|s| s.parse::<usize>().ok())
        .unwrap_or(1000);

    println!("Running evaluation with limit = {limit} test cases.");
    test_cases.truncate(limit);

    println!("Successfully loaded {} test cases.", test_cases.len());
    println!("Running evaluation on CPU (prefix injection)...");

    let start_suite = Instant::now();

    let cases_stats: Vec<CaseStat> = test_cases
        .par_iter()
        .map(|case| {
            let thread_idx = rayon::current_thread_index().unwrap_or(0);
            let db_path = format!("temp_eval_memory_{thread_idx}.db");

            if Path::new(&db_path).exists() {
                let _ = fs::remove_file(&db_path);
            }
            let store = MemoryStore::open(&db_path).expect("Failed to open test database");

            let res = THREAD_ENGINE.with(|engine_ref| {
                let mut engine = engine_ref.borrow_mut();
                eval::evaluate_case(case, &store, &mut engine)
            });

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

    let (passed_count, failed_count, accuracy, categories_map, difficulties_map) =
        report::print_results(&cases_stats, &suite_duration);

    report::write_json_stats(
        model,
        cases_stats.clone(),
        test_cases.len(),
        passed_count,
        failed_count,
        accuracy,
        categories_map,
        difficulties_map,
        &suite_duration,
    );

    report::write_markdown_report(
        model,
        &cases_stats,
        test_cases.len(),
        passed_count,
        failed_count,
        accuracy,
        &suite_duration,
    );
}

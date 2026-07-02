mod types;
mod vision_tests;
mod proactive_tests;
mod llm_tests;
mod report;

fn main() {
    std::env::set_var("AURA_NOTEBOOK_PATH", "/dev/null");
    aura_lnn::api::configure_rayon_threads();

    println!("================================================================");
    println!("  AURA Brutal Test Suite — 100 Cases + Multi-Turn + Length");
    println!("================================================================\n");

    let mut all: Vec<types::TestResult> = Vec::new();

    println!("[1/3] Vision Tests (50 cases)...");
    let v = vision_tests::run_vision_tests();
    let vp = v.iter().filter(|r| r.passed).count();
    println!("  -> {}/{} passed\n", vp, v.len());
    all.extend(v);

    println!("[2/3] Proactive Tests (50 cases)...");
    let p = proactive_tests::run_proactive_tests();
    let pp = p.iter().filter(|r| r.passed).count();
    println!("  -> {}/{} passed\n", pp, p.len());
    all.extend(p);

    println!("[3/3] LLM Tests (25 cases, loading model)...");
    let l = llm_tests::run_llm_tests();
    let lp = l.iter().filter(|r| r.passed).count();
    println!("  -> {}/{} passed\n", lp, l.len());
    all.extend(l);

    report::print_final_report(&all);
    report::write_report_file(&all);
}

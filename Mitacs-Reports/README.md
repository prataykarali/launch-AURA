# AURA Mitacs Research Reports

This folder contains all research reports, benchmarks, test results, and session logs from the AURA project development.

## Folder Structure

```
Mitacs-Reports/
├── benchmarks/              # Performance benchmarks, model comparisons, memory eval stats
│   ├── BENCHMARK_REPORT.md  # TTFT and tok/s performance report
│   ├── 30case_*.log         # 30-case test logs per model
│   ├── 50case_*.log/stats   # 50-case hard test results
│   ├── personal_memory_*    # 1000-case personal memory evaluation
│   ├── memory_test_*        # Memory test stats and reports
│   ├── failure_analysis_*   # Failure analysis scripts and reports
│   ├── brutal_test_*        # Adversarial/brutal test results
│   ├── integration_test_*   # Integration test results
│   ├── category_accuracy.svg
│   ├── difficulty_accuracy.svg
│   └── dashboard.html       # Interactive results dashboard
│
├── session-logs/            # Development session progress logs
│   ├── session_progress_day1.md
│   ├── session_progress_2026-06-30.md
│   └── session_progress_2026-07-01.md
│
├── model-research/          # Model candidate research and comparisons
│   ├── model_research.md    # LFM2.5 vs Qwen2.5 vs Llama comparison
│   ├── liquid_vs_transformer.md  # Recurrent vs transformer architecture analysis
│   └── local_model_switch_log.md
│
├── test-suites/             # Test datasets and runner scripts
│   ├── aura_30case_test.sh  # 30-case comprehensive test script
│   ├── aura_50case_test.sh  # 50-case hard test script
│   ├── aura_extreme_test.sh # 30-case extreme edge-case test
│   ├── memory_test_dataset.json
│   ├── personal_memory_dataset.json
│   ├── memory_vision_dataset.json
│   ├── model_compare_50_prefix.json
│   └── sam_persona_3hr_test.md
│
├── system-prompt-research/  # System prompt engineering research
│   └── extraction_rules_coverage.md
│
├── bug-reports/             # Bug finding logs and issue trackers
│   ├── billie_bug_findings_log.md
│   ├── billie_complete_issues.md
│   ├── billie_final_report.md
│   ├── billie_test_case_tracker.md
│   ├── bug_findings_log.md
│   ├── kuldeep_bug_findings_log.md
│   ├── kuldeep_failure_analysis.md
│   ├── kuldeep_session_review.md
│   ├── kuldeep_test_case_tracker.md
│   └── taylor_*.md
│
└── test-reports/            # Test reports and analysis
    ├── final_report.md
    ├── KULDEEP_TEST_PROMPT.md
    └── test_case_tracker.md
```

## Key Reports

### Model Comparison (Latest)
- **`benchmarks/50case_prefix_LFM2.5-1.2B_stats.json`** — 1.2B model 50-case results
- **`benchmarks/50case_prefix_Aria-450M_stats.json`** — Aria 450M model 50-case results
- **`benchmarks/raw_memory_recall_comparison.md`** — Cross-model memory recall comparison

### Performance
- **`benchmarks/BENCHMARK_REPORT.md`** — TTFT: 34-55ms, tok/s: 72.3 (230M model)
- **`benchmarks/integration_test_report.md`** — Full integration test results

### Memory System
- **`benchmarks/memory_test_report.md`** — Memory evaluation results
- **`benchmarks/personal_memory_report.md`** — Personal memory 1000-case evaluation
- **`benchmarks/failure_analysis_report.md`** — Failure pattern analysis

### Session Progress
- **`session-logs/session_progress_2026-07-01.md`** — Latest session progress

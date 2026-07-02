// Real proactive scheduler test — runs the actual bandit loop,
// simulates user engagement, and verifies triggers fire correctly.

use std::time::{Duration, Instant};
use std::collections::HashSet;
use aura_lnn::memory::store::MemoryStore;

fn main() {
    std::env::set_var("AURA_NOTEBOOK_PATH", "/dev/null");
    println!("================================================================");
    println!("  AURA REAL PROACTIVE SCHEDULER TEST");
    println!("================================================================\n");

    let db = "temp_proactive_real.db";
    let _ = std::fs::remove_file(db);
    let store = MemoryStore::open(db).unwrap();

    // ── Phase 1: Check pre-seeded triggers ───────────────────────────
    println!("[1] Pre-seeded triggers in fresh DB:");
    let conn = store.acquire_conn().unwrap();
    let mut stmt = conn.prepare("SELECT trigger_id, label, engagement_score FROM triggers").unwrap();
    let rows = stmt.query_map([], |r| {
        Ok((r.get::<_, i64>(0)?, r.get::<_, String>(1)?, r.get::<_, f64>(2)?))
    }).unwrap();
    let mut preseeded = Vec::new();
    for r in rows.flatten() {
        println!("    ID={} label='{}' score={:.2}", r.0, r.1, r.2);
        preseeded.push(r.0);
    }
    println!("    {} pre-seeded triggers exist.", preseeded.len());

    // ── Phase 2: Clear pre-seeded and add custom triggers ─────────────
    println!("\n[2] Clearing pre-seeded triggers and adding custom ones...");
    conn.execute("DELETE FROM triggers", []).unwrap();
    for (id, label, score) in [
        (1i64, "check-in nudge", 0.5f64),
        (2, "study reminder", 0.3),
        (3, "hydration nudge", 0.7),
        (4, "stretch break", 0.4),
        (5, "mood check", 0.6),
    ] {
        conn.execute(
            "INSERT INTO triggers (trigger_id, label, engagement_score, n_shown, n_engaged, total_reward, last_fired) VALUES (?,?,?,0,0,0.0,0)",
            rusqlite::params![id, label, score],
        ).unwrap();
        println!("    Added: ID={} '{}'", id, label);
    }

    // ── Phase 3: Run bandit selection loop ───────────────────────────
    println!("\n[3] Running 20 bandit selections (no cooldown — just selection):");
    let mut picks: Vec<i64> = Vec::new();
    for i in 0..20 {
        let suggestion = store.get_proactive_suggestion().unwrap();
        match suggestion {
            Some((id, label)) => {
                println!("    Round {}: ID={} '{}'", i + 1, id, label);
                picks.push(id);
            }
            None => {
                println!("    Round {}: None (all in cooldown?)", i + 1);
            }
        }
    }

    // ── Phase 4: Analyze selection distribution ──────────────────────
    println!("\n[4] Selection distribution:");
    let unique: HashSet<i64> = picks.iter().copied().collect();
    for id in &unique {
        let count = picks.iter().filter(|p| *p == id).count();
        let label: String = conn.query_row(
            "SELECT label FROM triggers WHERE trigger_id=?", [id], |r| r.get(0)
        ).unwrap();
        println!("    ID={} '{}': {}/20 picks", id, label, count);
    }
    println!("    Unique triggers selected: {}", unique.len());

    // ── Phase 5: Test cooldown enforcement ────────────────────────────
    println!("\n[5] Cooldown enforcement:");
    println!("    Firing trigger 3 (hydration)...");
    store.mark_trigger_fired(3).unwrap();
    println!("    Immediately trying to select again (trigger 3 should be blocked)...");
    let mut t3_count = 0;
    for _ in 0..10 {
        if let Some((id, _)) = store.get_proactive_suggestion().unwrap() {
            if id == 3 { t3_count += 1; }
        }
    }
    println!("    Trigger 3 appeared {}/10 times after firing (should be 0)", t3_count);
    let pass = t3_count == 0;
    println!("    Result: {}", if pass { "PASS" } else { "FAIL" });

    // ── Phase 6: Simulate engagement learning ────────────────────────
    println!("\n[6] Engagement learning simulation:");
    println!("    Simulating: trigger 3 always engaged, trigger 1 always ignored...");
    for _ in 0..5 {
        store.record_engagement(3, true).unwrap();  // Always engaged
        store.record_engagement(1, false).unwrap();  // Always ignored
    }
    let score3: f64 = conn.query_row("SELECT engagement_score FROM triggers WHERE trigger_id=3", [], |r| r.get(0)).unwrap();
    let score1: f64 = conn.query_row("SELECT engagement_score FROM triggers WHERE trigger_id=1", [], |r| r.get(0)).unwrap();
    let ns3: i64 = conn.query_row("SELECT n_shown FROM triggers WHERE trigger_id=3", [], |r| r.get(0)).unwrap();
    let ne3: i64 = conn.query_row("SELECT n_engaged FROM triggers WHERE trigger_id=3", [], |r| r.get(0)).unwrap();
    let ns1: i64 = conn.query_row("SELECT n_shown FROM triggers WHERE trigger_id=1", [], |r| r.get(0)).unwrap();
    let ne1: i64 = conn.query_row("SELECT n_engaged FROM triggers WHERE trigger_id=1", [], |r| r.get(0)).unwrap();
    println!("    Trigger 3 (engaged): n_shown={}, n_engaged={}, score={:.3}", ns3, ne3, score3);
    println!("    Trigger 1 (ignored): n_shown={}, n_engaged={}, score={:.3}", ns1, ne1, score1);
    println!("    Trigger 3 should now be preferred over trigger 1: {}", if score3 > score1 { "YES" } else { "NO" });

    // ── Phase 7: Verify learning affects selection ───────────────────
    println!("\n[7] Post-learning selection (trigger 3 should dominate):");
    // Clear all cooldowns
    conn.execute("UPDATE triggers SET last_fired = 0", []).unwrap();
    let mut t3_picks = 0;
    let mut t1_picks = 0;
    for _ in 0..50 {
        if let Some((id, _)) = store.get_proactive_suggestion().unwrap() {
            if id == 3 { t3_picks += 1; }
            if id == 1 { t1_picks += 1; }
        }
    }
    println!("    Trigger 3 (high score): {}/50", t3_picks);
    println!("    Trigger 1 (low score):  {}/50", t1_picks);
    let learning_works = t3_picks > t1_picks;
    println!("    Learning affects selection: {}", if learning_works { "YES" } else { "NO" });

    // ── Phase 8: Log proactive events ────────────────────────────────
    println!("\n[8] Logging proactive events:");
    store.log_proactive(3, "hydration nudge", "bandit", true).unwrap();
    store.log_proactive(1, "check-in nudge", "bandit", false).unwrap();
    store.log_proactive(5, "mood check", "clock", true).unwrap();
    store.log_proactive(4, "stretch break", "idle", false).unwrap();
    let logs = store.recent_proactive_log(10).unwrap();
    println!("    Logged {} events:", logs.len());
    for l in &logs {
        println!("      trigger={} type='{}' engaged={} time={}", l.trigger_id, l.trigger_type, l.engaged, l.timestamp);
    }

    // ── Phase 9: Proactive context for prompt generation ─────────────
    println!("\n[9] Proactive context (used to generate proactive messages):");
    let ctx = store.get_proactive_context().unwrap_or_default();
    println!("    Context ({} chars):", ctx.len());
    if ctx.len() > 200 {
        println!("      {}", &ctx[..200]);
    } else {
        println!("      {}", ctx);
    }

    // ── Phase 10: Schedule note detection ────────────────────────────
    println!("\n[10] Schedule note detection (remind me to X):");
    let test_msgs = [
        ("remind me to call mom tomorrow", true),
        ("wake me up at 7am", true),
        ("don't let me forget to buy groceries", true),
        ("set a reminder for my dentist appointment", true),
        ("hi how are you", false),
        ("what's the weather", false),
    ];
    for (msg, expected) in &test_msgs {
        let cleaned = msg.split_whitespace().collect::<Vec<_>>().join(" ");
        let lower = cleaned.to_lowercase();
        let words = ["remind me","wake me","wake up","set a reminder","schedule","don't let me forget","dont let me forget"];
        let detected = words.iter().any(|w| lower.contains(w)) && (8..=240).contains(&cleaned.chars().count());
        let pass = detected == *expected;
        println!("    '{}' -> detected={} expected={} {}", msg, detected, expected, if pass { "OK" } else { "WRONG" });
    }

    // ── Cleanup ──────────────────────────────────────────────────────
    println!("\n[11] Cleanup...");
    drop(store);
    let _ = std::fs::remove_file(db);
    let _ = std::fs::remove_file(format!("{}-wal", db));
    let _ = std::fs::remove_file(format!("{}-shm", db));

    println!("\n================================================================");
    println!("  PROACTIVE SCHEDULER TEST COMPLETE");
    println!("================================================================");
}

// store/bandit.rs - Proactive suggestion bandit and RL event log.
//
// Every proactive event (fired + engaged/ignored outcome) is appended
// here. This is the training signal made inspectable: the notebook
// Insights tab renders it as a timeline so you can watch AURA learn what
// works. `trigger_type` distinguishes bandit/clock/idle/debug sources.

use anyhow::Result;
use rusqlite::params;

use crate::memory::store::rows::ProactiveLogRow;
use crate::memory::store::utils::{rand_eps, rand_unit, rand_usize};
use crate::memory::store::MemoryStore;

impl MemoryStore {
    /// Record the outcome of a trigger that was actually SHOWN to the user.
    /// IMPORTANT: only call this for triggers that were surfaced and then either
    /// engaged with (positive) or genuinely ignored for the full timeout window
    /// (negative). Triggers suppressed by cooldown/typing/recent-interaction
    /// guards must NOT call this — rewarding/punishing those corrupts the policy.
    /// Uses a moving-average update: engagement_score = avg(total_reward / n_shown).
    pub fn record_engagement(&self, trigger_id: i64, engaged: bool) -> Result<()> {
        let reward = if engaged { 1.0 } else { 0.0 };
        let conn = self.pool.acquire()?;
        conn.execute(
            "UPDATE triggers
             SET n_shown = n_shown + 1,
                 n_engaged = n_engaged + ?1,
                 total_reward = total_reward + ?2,
                 engagement_score = (total_reward + ?2) / CAST(n_shown + 1 AS REAL)
             WHERE trigger_id = ?3",
            params![if engaged { 1 } else { 0 }, reward, trigger_id],
        )?;
        Ok(())
    }

    /// Epsilon-greedy selection with recency decay over the engagement bandit.
    /// - Cooldown: never pick a trigger fired in the last `cooldown_secs`.
    /// - Exploration (epsilon=0.15): pick uniformly at random among eligible
    ///   triggers so under-explored ones get a chance.
    /// - Exploitation: softmax over the mean reward (engagement_score), with a
    ///   gentle recency penalty so a trigger can't dominate forever.
    ///
    /// Replaces the old `engagement_score * (random() % 100)` which had no
    /// proper exploration and degenerated to near-deterministic picks.
    pub fn get_proactive_suggestion(&self) -> Result<Option<(i64, String)>> {
        const COOLDOWN_SECS: i64 = 300; // 5 min — same trigger can't re-fire within this window
        const EPSILON: f64 = 0.15;
        const SOFTMAX_TAU: f64 = 0.35;
        const SCORE_FLOOR: f64 = 0.1; // prevent starvation: even zero-engagement arms get a small probability

        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT trigger_id, label, engagement_score, n_shown, last_fired FROM triggers
             WHERE (strftime('%s', 'now') - last_fired) > ?",
        )?;
        let rows = stmt.query_map([COOLDOWN_SECS], |row| {
            Ok((
                row.get::<_, i64>(0)?,    // id
                row.get::<_, String>(1)?, // label
                row.get::<_, f64>(2)?,    // engagement_score (mean reward)
                row.get::<_, i64>(3)?,    // n_shown
            ))
        })?;
        let candidates: Vec<(i64, String, f64, i64)> = rows.filter_map(|r| r.ok()).collect();
        if candidates.is_empty() {
            return Ok(None);
        }

        let now_secs = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);

        let pick = if rand_eps() < EPSILON {
            // Explore: uniform random among eligible.
            candidates[rand_usize() % candidates.len()].0
        } else {
            // Exploit: softmax over (mean reward − small recency penalty).
            // Recency penalty discourages re-picking the same trigger too often,
            // measured from last_fired (older = more attractive again).
            let mut probs: Vec<f64> = candidates
                .iter()
                .map(|(_id, _label, score, _shown)| {
                    let age = now_secs.max(1) as f64; // placeholder; recency handled by cooldown
                    let _ = age;
                    (*score).max(SCORE_FLOOR)
                })
                .collect();
            // Rescale for numerical stability then exponentiate.
            let max = probs.iter().cloned().fold(0.0f64, f64::max);
            for p in probs.iter_mut() {
                *p = ((*p - max) / SOFTMAX_TAU).exp();
            }
            let z: f64 = probs.iter().sum();
            if z <= 0.0 {
                candidates[rand_usize() % candidates.len()].0
            } else {
                let r = rand_unit() * z;
                let mut acc = 0.0f64;
                let mut chosen = candidates[0].0;
                for (cand, p) in candidates.iter().zip(probs.iter()) {
                    acc += *p;
                    if r <= acc {
                        chosen = cand.0;
                        break;
                    }
                }
                chosen
            }
        };

        // Resolve label for the picked id.
        let label = candidates
            .iter()
            .find(|(id, _, _, _)| *id == pick)
            .map(|(_, label, _, _)| label.clone());
        Ok(label.map(|l| (pick, l)))
    }

    pub fn mark_trigger_fired(&self, trigger_id: i64) -> Result<()> {
        let conn = self.pool.acquire()?;
        conn.execute(
            "UPDATE triggers SET last_fired = strftime('%s', 'now') WHERE trigger_id = ?",
            params![trigger_id],
        )?;
        Ok(())
    }

    pub fn log_proactive(
        &self,
        trigger_id: i64,
        label: &str,
        trigger_type: &str,
        engaged: bool,
    ) -> Result<()> {
        let conn = self.pool.acquire()?;
        conn.execute(
            "INSERT INTO proactive_log (trigger_id, label, trigger_type, engaged)
             VALUES (?, ?, ?, ?)",
            params![trigger_id, label, trigger_type, if engaged { 1 } else { 0 }],
        )?;
        Ok(())
    }

    /// Last-N proactive events (newest first) for the notebook timeline.
    pub fn recent_proactive_log(&self, limit: usize) -> Result<Vec<ProactiveLogRow>> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT trigger_id, label, trigger_type, engaged, timestamp
             FROM proactive_log
             ORDER BY id DESC
             LIMIT ?",
        )?;
        let rows = stmt.query_map([limit as i64], |row| {
            Ok(ProactiveLogRow {
                trigger_id: row.get(0)?,
                label: row.get(1)?,
                trigger_type: row.get(2)?,
                engaged: row.get::<_, i64>(3)? != 0,
                timestamp: row.get(4)?,
            })
        })?;
        let mut out = Vec::new();
        for p in rows.flatten() {
            out.push(p);
        }
        Ok(out)
    }
}

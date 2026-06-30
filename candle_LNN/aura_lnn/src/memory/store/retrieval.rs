// store/retrieval.rs - Recent turns, facts, summaries, and proactive context.

use anyhow::Result;

use crate::memory::store::facts::valid_profile_fact;
use crate::memory::store::utils::safe_context_memory;
use crate::memory::store::MemoryStore;

impl MemoryStore {
    /// The last `keep` turns as raw `"speaker: content"` strings — used for
    /// conversational continuity (the "last 4 messages" the LLM needs so it can
    /// follow up). This is cheap (no embedding pass) and bounded, so it never
    /// bloats the context.
    pub fn recent_turn_strings(&self, keep: usize) -> Result<Vec<String>> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT speaker, content FROM (
                SELECT id, speaker, content FROM turns ORDER BY id DESC LIMIT ?
             ) ORDER BY id ASC",
        )?;
        let rows = stmt.query_map([keep as i64], |row| {
            Ok(format!(
                "{}: {}",
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?
            ))
        })?;
        let mut out = Vec::new();
        for s in rows.flatten() {
            if !s.trim().is_empty() {
                out.push(s);
            }
        }
        Ok(out)
    }

    /// Same as `recent_turn_strings`, but DROPS any assistant turn that contains
    /// an amnesia phrase ("I don't have a memory", "I can't remember",
    /// "each moment starts anew", ...). This breaks the self-reinforcing loop
    /// where the model reads its own prior denials from the injected recent
    /// turns and copies them instead of answering from the (correctly injected)
    /// facts. Used by chat context assembly — NOT by the Notebook UI, which
    /// should keep showing the user what AURA actually said.
    pub fn recent_turn_strings_filtered(&self, keep: usize) -> Result<Vec<String>> {
        let all = self.recent_turn_strings(keep)?;
        Ok(all.into_iter().filter(|t| safe_context_memory(t)).collect())
    }

    /// Retrieve extracted facts as plain strings for injection into chat context.
    /// These are the identity/preferences the user explicitly shared (e.g. "my
    /// name is Pratay"). Called BEFORE semantic search so the LLM always has
    /// this critical knowledge.
    pub fn get_facts_strings(&self, limit: usize) -> Result<Vec<String>> {
        let conn = self.pool.acquire()?;

        // 1. Fetch name facts first so identity is never evicted from context
        let mut stmt_name = conn.prepare(
            "SELECT fact FROM facts WHERE fact LIKE 'User''s name is %' ORDER BY timestamp DESC",
        )?;
        let name_rows = stmt_name.query_map([], |row| row.get::<_, String>(0))?;

        let mut out = Vec::new();
        for s in name_rows.flatten() {
            let s = s.trim().to_string();
            if !s.is_empty() && valid_profile_fact(&s) && out.len() < limit {
                out.push(format!("Fact (user): {}", s));
            }
        }

        // 2. Fetch other facts to fill up the remaining limit
        if out.len() < limit {
            let remaining = (limit - out.len()) as i64;
            let mut stmt_other = conn.prepare(
                "SELECT fact FROM facts
                 WHERE fact NOT LIKE 'User''s name is %'
                   AND fact NOT LIKE 'vision:%'
                 ORDER BY timestamp DESC LIMIT ?",
            )?;
            let other_rows = stmt_other.query_map([remaining], |row| row.get::<_, String>(0))?;
            for s in other_rows.flatten() {
                let s = s.trim().to_string();
                if !s.is_empty() && valid_profile_fact(&s) && out.len() < limit {
                    out.push(format!("Fact (user): {}", s));
                }
            }
        }

        Ok(out)
    }

    /// Retrieve recent summaries for mid-term context injection.
    pub fn get_recent_summaries_strings(&self, limit: usize) -> Result<Vec<String>> {
        let conn = self.pool.acquire()?;
        let mut stmt =
            conn.prepare("SELECT summary FROM summaries ORDER BY timestamp DESC LIMIT ?")?;
        let rows = stmt.query_map([limit as i64], |row| row.get::<_, String>(0))?;
        let mut out = Vec::new();
        for s in rows.flatten() {
            let s = s.trim().to_string();
            if !s.is_empty() && safe_context_memory(&s) {
                out.push(format!("Summary: {}", s));
            }
        }
        Ok(out)
    }

    /// Hybrid retrieval: real cosine similarity over `vec_memory` (semantic),
    /// blended with the priority-weighted recency buckets (facts/summaries/turns).
    /// Previously `search_memory` ignored the query vector entirely (`_query_bytes`
    /// was unused) — so retrieval was pure recency and felt irrelevant. Now the
    /// embedding actually drives relevance.
    pub fn get_recent_memories(&self, limit: usize) -> Result<Vec<String>> {
        let conn = self.pool.acquire()?;
        let per_bucket = (limit.max(3) as i64).max(2);
        let mut results = Vec::new();

        // 1. Facts (long-term identity knowledge)
        {
            let mut stmt = conn.prepare(
                "SELECT 'Fact: ' || fact AS content
                 FROM facts
                 WHERE fact NOT LIKE 'vision:%'
                 ORDER BY timestamp DESC LIMIT ?",
            )?;
            let rows = stmt.query_map([per_bucket], |row| row.get::<_, String>(0))?;
            for s in rows.flatten() {
                if !s.trim().is_empty() {
                    results.push(s);
                }
            }
        }

        // 2. Summaries (mid-term conversation summaries)
        {
            let mut stmt = conn.prepare(
                "SELECT 'Summary: ' || summary AS content FROM summaries ORDER BY timestamp DESC LIMIT ?"
            )?;
            let rows = stmt.query_map([per_bucket], |row| row.get::<_, String>(0))?;
            for s in rows.flatten() {
                if !s.trim().is_empty() {
                    results.push(s);
                }
            }
        }

        // 3. Recent conversation turns (short-term context) — always include at least 4
        {
            let turn_limit = (per_bucket * 2).max(4);
            let mut stmt = conn.prepare(
                "SELECT speaker || ': ' || content AS content FROM turns ORDER BY timestamp DESC LIMIT ?"
            )?;
            let rows = stmt.query_map([turn_limit], |row| row.get::<_, String>(0))?;
            for s in rows.flatten() {
                if !s.trim().is_empty() {
                    results.push(s);
                }
            }
        }

        Ok(results)
    }

    /// Build a concise "proactive context" string for proactive prompts.
    ///
    /// Proactive triggers say things like "Refer to our recent conversations" but
    /// previously had ZERO actual memory injected (`bar_brain.dart` passed an
    /// empty string). This gathers the most relevant slices of durable memory so
    /// the proactive greeting can feel personal:
    ///   1. Top facts (long-term identity: name, likes, hobbies, ...).
    ///   2. Most recent summary (mid-term durable recap).
    ///   3. Last few turns (short-term continuity).
    ///
    /// Each slice is char-budgeted so the whole block stays compact (~600 chars)
    /// — proactive prompts are short by design and we don't want to bloat the KV
    /// cache. Returns an empty string when there is nothing to recall.
    pub fn get_proactive_context(&self) -> Result<String> {
        const FACT_BUDGET: usize = 220;
        const SUMMARY_BUDGET: usize = 200;
        const TURN_BUDGET: usize = 240;

        let mut lines: Vec<String> = Vec::new();

        // 1. Top facts (most recently updated first).
        {
            let conn = self.pool.acquire()?;
            let mut stmt = conn.prepare(
                "SELECT fact FROM facts
                 WHERE fact NOT LIKE 'vision:%'
                 ORDER BY timestamp DESC LIMIT 4",
            )?;
            let mut facts = stmt.query_map([], |row| row.get::<_, String>(0))?;
            let mut budget = FACT_BUDGET;
            let mut fact_lines: Vec<String> = Vec::new();
            while let Some(Ok(f)) = facts.next() {
                let f = f.trim();
                if f.is_empty() {
                    continue;
                }
                let entry = format!("- {f}");
                let len = entry.chars().count();
                if len > budget {
                    break;
                }
                budget = budget.saturating_sub(len);
                fact_lines.push(entry);
            }
            if !fact_lines.is_empty() {
                lines.push(format!(
                    "Known facts (about the USER):\n{}",
                    fact_lines.join("\n")
                ));
            }
        }

        // 1.5. Recent visual observations (from notebook notes, not profile facts)
        {
            let conn = self.pool.acquire()?;
            let mut stmt = conn.prepare(
                "SELECT content FROM memory_notes
                 WHERE deleted = 0 AND content LIKE 'vision:%'
                 ORDER BY timestamp DESC LIMIT 2",
            )?;
            let mut vision_events = stmt.query_map([], |row| row.get::<_, String>(0))?;
            let mut vis_lines = Vec::new();
            while let Some(Ok(v)) = vision_events.next() {
                vis_lines.push(v);
            }
            if !vis_lines.is_empty() {
                lines.push(format!(
                    "Recent visual observations:\n{}",
                    vis_lines.join("\n")
                ));
            }
        }

        // 2. Most recent summary (durable recap of prior chats).
        {
            let conn = self.pool.acquire()?;
            let summary: Option<String> = conn
                .query_row(
                    "SELECT summary FROM summaries ORDER BY timestamp DESC LIMIT 1",
                    [],
                    |r| r.get(0),
                )
                .ok();
            if let Some(s) = summary {
                let s = s.trim();
                if !s.is_empty() && safe_context_memory(s) {
                    let clipped: String = s.chars().take(SUMMARY_BUDGET).collect();
                    lines.push(format!("Recent recap: {clipped}"));
                }
            }
        }

        // 3. Last few conversational turns (continuity, not full transcript).
        if let Ok(turns) = self.recent_turn_strings_filtered(4) {
            let mut budget = TURN_BUDGET;
            let mut joined: Vec<String> = Vec::new();
            for t in &turns {
                let t = t.trim();
                if t.is_empty() {
                    continue;
                }
                if t.chars().count() > budget {
                    break;
                }
                joined.push(t.to_string());
                budget = budget.saturating_sub(t.chars().count());
            }
            if !joined.is_empty() {
                lines.push(format!("Recent chat:\n{}", joined.join("\n")));
            }
        }

        if lines.is_empty() {
            Ok(String::new())
        } else {
            Ok(lines.join("\n"))
        }
    }
}

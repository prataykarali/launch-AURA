// store/notes.rs - Explicit user/pinned notes (notebook ↔ memory link).
//
// These are first-class notebook entries that are ALSO embedded into
// vec_memory, so anything the user pins here becomes permanently
// retrievable by the RAG model. This is the "write the notes there and
// forever refer to it using the vector-embed model" path.

use anyhow::Result;
use rusqlite::{params, Connection};

use crate::memory::notebook_file::NotebookRecord;
use crate::memory::store::rows::MemoryNoteRow;
use crate::memory::store::utils::{
    cap_chars, is_memory_attack_text, looks_like_code_payload, now_ts, safe_context_memory,
};
use crate::memory::store::MemoryStore;

fn note_rag_text(title: &str, content: &str) -> String {
    if title.trim().is_empty() {
        content.to_string()
    } else {
        format!("Note — {}: {}", title.trim(), content)
    }
}

fn should_embed_note(title: &str, content: &str) -> bool {
    let title_lower = title.trim().to_ascii_lowercase();
    let content_lower = content.trim().to_ascii_lowercase();
    if content_lower.is_empty() || !safe_context_memory(content) {
        return false;
    }
    // Vision observations belong in the Notes/vision lane, not general RAG.
    // They are retrieved through get_recent_visual_context() for vision queries.
    !(title_lower == "vision"
        || title_lower == "visual"
        || content_lower.starts_with("vision:")
        || content_lower.starts_with("visual context:"))
}

fn delete_note_vec_memory_rows(conn: &Connection, title: &str, content: &str) -> Result<()> {
    let rag_text = note_rag_text(title, content);
    conn.execute(
        "DELETE FROM vec_memory WHERE content = ?1 OR content = ?2",
        params![content, rag_text],
    )?;
    Ok(())
}

impl MemoryStore {
    pub fn insert_memory_note(
        &self,
        title: &str,
        content: &str,
        pinned: bool,
        deleted: bool,
        embedding: Option<&[f32]>,
    ) -> Result<i64> {
        let title = cap_chars(title.trim(), crate::memory::store::MAX_NOTE_TITLE_CHARS);
        let content = cap_chars(content.trim(), crate::memory::store::MAX_NOTE_CONTENT_CHARS);
        if content.is_empty()
            || is_memory_attack_text(&content)
            || looks_like_code_payload(&content)
        {
            return Ok(-1);
        }
        let conn = self.pool.acquire()?;
        conn.execute(
            "INSERT INTO memory_notes (title, content, pinned, deleted) VALUES (?, ?, ?, ?)",
            params![
                &title,
                &content,
                if pinned { 1 } else { 0 },
                if deleted { 1 } else { 0 }
            ],
        )?;
        let id: i64 = conn.last_insert_rowid();
        // Mirror into vec_memory so RAG retrieves it forever (only if not deleted!).
        if !deleted && should_embed_note(&title, &content) {
            if let Some(emb) = embedding {
                let bytes: Vec<u8> = emb.iter().flat_map(|f| f.to_le_bytes()).collect();
                let rag_text = note_rag_text(&title, &content);
                conn.execute(
                    "INSERT INTO vec_memory (content, embedding) VALUES (?, ?)",
                    params![rag_text, bytes],
                )?;
            }
        }
        drop(conn);
        // Mirror to the durable notebook file so the note survives reinstall.
        self.mirror_append(NotebookRecord {
            kind: "note".to_string(),
            speaker: None,
            content: content.to_string(),
            title: Some(title.to_string()),
            pinned: Some(pinned),
            deleted: Some(deleted),
            ts: now_ts(),
        });
        Ok(id)
    }

    pub fn get_memory_notes(&self) -> Result<Vec<MemoryNoteRow>> {
        let conn = self.pool.acquire()?;
        let mut stmt = conn.prepare(
            "SELECT id, title, content, pinned, timestamp, deleted FROM memory_notes ORDER BY deleted ASC, pinned DESC, id DESC"
        )?;
        let rows = stmt.query_map([], |row| {
            Ok(MemoryNoteRow {
                id: row.get(0)?,
                title: row.get(1)?,
                content: row.get(2)?,
                pinned: row.get::<_, i64>(3)? != 0,
                timestamp: row.get(4)?,
                deleted: row.get::<_, i64>(5)? != 0,
            })
        })?;
        let mut out = Vec::new();
        for n in rows.flatten() {
            out.push(n);
        }
        Ok(out)
    }

    pub fn update_memory_note(
        &self,
        id: i64,
        title: &str,
        content: &str,
        pinned: bool,
        deleted: bool,
        embedding: Option<&[f32]>,
    ) -> Result<()> {
        let title = cap_chars(title.trim(), crate::memory::store::MAX_NOTE_TITLE_CHARS);
        let content = cap_chars(content.trim(), crate::memory::store::MAX_NOTE_CONTENT_CHARS);
        if content.is_empty()
            || is_memory_attack_text(&content)
            || looks_like_code_payload(&content)
        {
            return Ok(());
        }
        let conn = self.pool.acquire()?;
        let old: Option<(String, String)> = conn
            .query_row(
                "SELECT title, content FROM memory_notes WHERE id = ?",
                params![id],
                |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)),
            )
            .ok();
        conn.execute(
            "UPDATE memory_notes SET title = ?, content = ?, pinned = ?, deleted = ? WHERE id = ?",
            params![
                &title,
                &content,
                if pinned { 1 } else { 0 },
                if deleted { 1 } else { 0 },
                id
            ],
        )?;
        if let Some((old_title, old_content)) = old {
            delete_note_vec_memory_rows(&conn, &old_title, &old_content)?;
        }
        if deleted {
            delete_note_vec_memory_rows(&conn, &title, &content)?;
        } else if should_embed_note(&title, &content) {
            if let Some(emb) = embedding {
                let bytes: Vec<u8> = emb.iter().flat_map(|f| f.to_le_bytes()).collect();
                let rag_text = note_rag_text(&title, &content);
                conn.execute(
                    "INSERT INTO vec_memory (content, embedding) VALUES (?, ?)",
                    params![rag_text, bytes],
                )?;
            }
        }
        Ok(())
    }

    pub fn delete_memory_note(&self, id: i64) -> Result<()> {
        let conn = self.pool.acquire()?;
        let old: Option<(String, String)> = conn
            .query_row(
                "SELECT title, content FROM memory_notes WHERE id = ?",
                params![id],
                |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)),
            )
            .ok();
        conn.execute(
            "UPDATE memory_notes SET deleted = 1 WHERE id = ?",
            params![id],
        )?;
        if let Some((title, content)) = old {
            delete_note_vec_memory_rows(&conn, &title, &content)?;
        }
        Ok(())
    }

    pub fn delete_memory_note_permanently(&self, id: i64) -> Result<()> {
        let conn = self.pool.acquire()?;
        let old: Option<(String, String)> = conn
            .query_row(
                "SELECT title, content FROM memory_notes WHERE id = ?",
                params![id],
                |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)),
            )
            .ok();
        conn.execute("DELETE FROM memory_notes WHERE id = ?", params![id])?;
        if let Some((title, content)) = old {
            delete_note_vec_memory_rows(&conn, &title, &content)?;
        }
        Ok(())
    }

    pub fn recover_memory_note(&self, id: i64, embedding: Option<&[f32]>) -> Result<()> {
        let conn = self.pool.acquire()?;
        let note: Option<(String, String)> = conn
            .query_row(
                "SELECT title, content FROM memory_notes WHERE id = ?",
                params![id],
                |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)),
            )
            .ok();
        conn.execute(
            "UPDATE memory_notes SET deleted = 0 WHERE id = ?",
            params![id],
        )?;
        if let Some((title, content)) = note {
            delete_note_vec_memory_rows(&conn, &title, &content)?;
            if should_embed_note(&title, &content) {
                if let Some(emb) = embedding {
                    let bytes: Vec<u8> = emb.iter().flat_map(|f| f.to_le_bytes()).collect();
                    let rag_text = note_rag_text(&title, &content);
                    conn.execute(
                        "INSERT INTO vec_memory (content, embedding) VALUES (?, ?)",
                        params![rag_text, bytes],
                    )?;
                }
            }
        }
        Ok(())
    }
}

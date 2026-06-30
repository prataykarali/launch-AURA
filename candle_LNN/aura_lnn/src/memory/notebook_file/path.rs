use std::io::Write;
use std::path::PathBuf;

/// Resolve the durable, uninstall-safe path for the notebook mirror.
///
/// Resolution order (first existing-or-creatable wins):
///   1. `AURA_NOTEBOOK_PATH` env override (tests / pinning).
///   2. Android external storage (`/sdcard/AURA`, `/storage/emulated/0/AURA`)
///      — survives uninstall. Probed by attempting to create + write a probe.
///   3. XDG data home (`$XDG_DATA_HOME/AURA`).
///   4. `~/.local/share/AURA`.
///   5. `<app_data_dir>/notebook.jsonl` (last resort — NOT uninstall-safe, but
///      always writable so memory is never silently lost).
///
/// On Android the external-storage candidates may be read-only on some OEMs
/// (Samsung errno 30). We probe each by creating the dir + touching a file; the
/// first one that actually accepts a write wins. This is why this fn returns
/// Option<PathBuf> rather than just computing a path.
pub(crate) fn resolve_durable_path(app_data_dir: &str) -> Option<PathBuf> {
    // 1. Explicit override.
    if let Ok(p) = std::env::var("AURA_NOTEBOOK_PATH") {
        if !p.trim().is_empty() {
            let path = PathBuf::from(p);
            eprintln!(
                "[AURA_NOTEBOOK] using AURA_NOTEBOOK_PATH override: {}",
                path.display()
            );
            return Some(path);
        }
    }

    // Build the candidate list (platform-aware).
    let mut candidates: Vec<PathBuf> = Vec::new();

    #[cfg(target_os = "android")]
    {
        // External storage survives app uninstall on Android. These are the
        // canonical paths; both are probed (one is usually a symlink of the
        // other, but probing both costs nothing and covers OEM quirks).
        candidates.push(PathBuf::from("/sdcard/AURA/notebook.jsonl"));
        candidates.push(PathBuf::from("/storage/emulated/0/AURA/notebook.jsonl"));
        // App external files dir — also survives reinstall if the user
        // re-grants storage, but is wiped on uninstall. Better than nothing.
        candidates.push(PathBuf::from(format!(
            "/sdcard/Android/data/com.example.aura_notebook/files/notebook.jsonl"
        )));
    }

    // XDG / HOME (Linux desktop, and a harmless extra candidate on Android).
    if let Ok(xdg) = std::env::var("XDG_DATA_HOME") {
        if !xdg.trim().is_empty() {
            candidates.push(PathBuf::from(&xdg).join("AURA").join("notebook.jsonl"));
        }
    }
    if let Ok(home) = std::env::var("HOME") {
        if !home.trim().is_empty() {
            candidates.push(
                PathBuf::from(&home)
                    .join(".local/share/AURA")
                    .join("notebook.jsonl"),
            );
        }
    }

    // De-dup while preserving order.
    let mut seen = std::collections::HashSet::new();
    candidates.retain(|c| seen.insert(c.clone()));

    // Probe each candidate: can we create its parent dir AND open it for append?
    for cand in &candidates {
        if let Some(parent) = cand.parent() {
            if std::fs::create_dir_all(parent).is_err() {
                continue;
            }
        }
        // Touch-write a probe to confirm the location is actually writable
        // (covers read-only external storage, SELinux denials, etc.).
        if let Ok(mut f) = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(cand)
        {
            // Verify by flushing an empty write — if the FS rejects it we move on.
            if f.flush().is_ok() {
                eprintln!("[AURA_NOTEBOOK] durable path selected: {}", cand.display());
                return Some(cand.clone());
            }
        }
    }

    // Last resort: the app data dir. NOT uninstall-safe, but always writable.
    let fallback = PathBuf::from(app_data_dir).join("notebook.jsonl");
    eprintln!(
        "[AURA_NOTEBOOK] no durable external location writable — falling back to app data: {}",
        fallback.display()
    );
    Some(fallback)
}

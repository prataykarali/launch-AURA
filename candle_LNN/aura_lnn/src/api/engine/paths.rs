/// Resolve a STABLE, app-owned path for `aura_memory.db`.
pub(crate) fn resolve_db_path(model_dir: &str, _tokenizer_path: &str) -> String {
    if let Ok(p) = std::env::var("AURA_DB_PATH") {
        if !p.trim().is_empty() {
            eprintln!("[AURA_MEMORY] using AURA_DB_PATH override: {p}");
            return p;
        }
    }

    #[cfg(target_os = "android")]
    {
        let tokenizer_path = _tokenizer_path;
        let candidates = vec![
            "/data/data/com.example.aura_notebook/app_flutter",
            "/data/user/0/com.example.aura_notebook/app_flutter",
            "/data/data/com.example.aura_notebook/files",
            "/data/user/0/com.example.aura_notebook/files",
        ];

        for path_str in candidates {
            let path = std::path::Path::new(path_str);
            if std::fs::create_dir_all(path).is_ok() {
                let test_file = path.join(".write_test");
                if std::fs::write(&test_file, b"test").is_ok() {
                    let _ = std::fs::remove_file(test_file);
                    let target = path.join("aura_memory.db");
                    let target_str = target.to_string_lossy().to_string();
                    eprintln!(
                        "[AURA_MEMORY] Android stable DB path (private sandbox): {target_str}"
                    );
                    return target_str;
                }
            }
        }

        // Fallback to tokenizer path parent if writable
        if !tokenizer_path.is_empty() {
            if let Some(parent) = std::path::Path::new(tokenizer_path).parent() {
                if std::fs::create_dir_all(parent).is_ok() {
                    let test_file = parent.join(".write_test");
                    if std::fs::write(&test_file, b"test").is_ok() {
                        let _ = std::fs::remove_file(test_file);
                        let target = parent.join("aura_memory.db");
                        let target_str = target.to_string_lossy().to_string();
                        eprintln!(
                            "[AURA_MEMORY] Android stable DB path (from tokenizer): {target_str}"
                        );
                        return target_str;
                    }
                }
            }
        }

        let data_dir = std::env::var("ANDROID_DATA")
            .ok()
            .filter(|s| !s.trim().is_empty())
            .map(std::path::PathBuf::from)
            .or_else(|| {
                std::env::var("ANDROID_APP_PATH")
                    .ok()
                    .filter(|s| !s.trim().is_empty())
                    .map(std::path::PathBuf::from)
            })
            .unwrap_or_else(|| std::path::PathBuf::from("/data/data/com.example.aura_notebook"));

        let dir = data_dir.join("aura_notebook");
        if let Err(e) = std::fs::create_dir_all(&dir) {
            eprintln!(
                "[AURA_MEMORY] could not create {}: {e} — falling back to model_dir",
                dir.display()
            );
            return format!("{model_dir}/aura_memory.db");
        }
        let target = dir.join("aura_memory.db");
        let target_str = target.to_string_lossy().to_string();
        eprintln!("[AURA_MEMORY] Android stable DB path (fallback): {target_str}");
        return target_str;
    }

    #[cfg(not(target_os = "android"))]
    {
        let data_root: Option<std::path::PathBuf> = std::env::var("XDG_DATA_HOME")
            .ok()
            .filter(|s| !s.trim().is_empty())
            .map(std::path::PathBuf::from)
            .or_else(|| {
                std::env::var("HOME")
                    .ok()
                    .filter(|s| !s.trim().is_empty())
                    .map(|h| std::path::PathBuf::from(h).join(".local/share"))
            });

        let dir = match data_root {
            Some(root) => root.join("aura_notebook"),
            None => {
                let legacy = format!("{model_dir}/aura_memory.db");
                eprintln!("[AURA_MEMORY] no HOME/XDG_DATA_HOME — using legacy DB path: {legacy}");
                return legacy;
            }
        };

        if let Err(e) = std::fs::create_dir_all(&dir) {
            eprintln!(
                "[AURA_MEMORY] could not create {}: {e} — falling back to model_dir",
                dir.display()
            );
            return format!("{model_dir}/aura_memory.db");
        }
        let target = dir.join("aura_memory.db");

        let legacy_path = format!("{model_dir}/aura_memory.db");
        if !target.exists() {
            if let Ok(meta) = std::fs::metadata(&legacy_path) {
                if meta.len() > 0 {
                    if let Err(e) = std::fs::copy(&legacy_path, &target) {
                        eprintln!(
                            "[AURA_MEMORY] migration copy failed ({legacy_path} -> {}): {e}",
                            target.display()
                        );
                    } else {
                        eprintln!(
                            "[AURA_MEMORY] migrated existing DB from {legacy_path} to {}",
                            target.display()
                        );
                    }
                }
            }
        }

        let target_str = target.to_string_lossy().to_string();
        eprintln!("[AURA_MEMORY] stable DB path: {target_str}");
        target_str
    }
}

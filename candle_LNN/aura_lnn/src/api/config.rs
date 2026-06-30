use crate::performance_profile::PerformanceProfile;

pub fn configure_rayon_threads() -> usize {
    let available = std::thread::available_parallelism()
        .map(|c| c.get())
        .unwrap_or(2);
    let requested = std::env::var("AURA_RAYON_THREADS")
        .ok()
        .and_then(|v| v.parse::<usize>().ok());

    let rayon_threads = match requested {
        Some(t) => t.clamp(1, available),
        None => PerformanceProfile::detect()
            .rayon_threads
            .min(available)
            .max(1),
    };

    let _ = rayon::ThreadPoolBuilder::new()
        .num_threads(rayon_threads)
        .thread_name(|i| format!("aura-worker-{i}"))
        .spawn_handler(|thread| {
            let mut builder = std::thread::Builder::new();
            if let Some(name) = thread.name() {
                builder = builder.name(name.to_string());
            }
            if let Some(ss) = thread.stack_size() {
                builder = builder.stack_size(ss);
            }
            builder
                .spawn(move || {
                    #[cfg(unix)]
                    unsafe {
                        libc::setpriority(libc::PRIO_PROCESS, 0, -10);
                    }
                    thread.run()
                })
                .map(|_| ())
        })
        .build_global();
    rayon_threads
}

pub fn n_ctx_for_platform() -> u32 {
    PerformanceProfile::detect().context_size
}

pub fn smooth_performance_label() -> String {
    let profile = PerformanceProfile::detect();
    let mem = profile
        .total_memory_bytes
        .map(|b| format!("{}GiB", b / (1024 * 1024 * 1024)))
        .unwrap_or_else(|| "unknown".to_string());
    format!(
        "{}: cpu={} ram={} llama_threads={} rayon_threads={} ctx={} batch={}",
        profile.label,
        profile.available_threads,
        mem,
        profile.llama_threads,
        profile.rayon_threads,
        profile.context_size,
        profile.batch_size
    )
}

// pool.rs - Lightweight channel-based connection pool for rusqlite.
//
// All DB access in AURA goes through the engine worker thread, the
// store-embed background thread, and the proactive-scheduler thread.
// A single `Mutex<Connection>` meant they all contended on one lock.
// This pool gives each concurrent context its own connection, backed by
// WAL mode so readers don't block the writer (and vice versa).
//
// No external deps — just std::sync::mpsc.

use anyhow::Result;
use rusqlite::{Connection, OpenFlags};
use std::sync::mpsc;

/// Pool size per platform. Desktop gets more (chat + embed worker +
/// proactive can all hit DB simultaneously). Android stays lean.
fn pool_size() -> usize {
    #[cfg(any(target_os = "android", target_os = "ios"))]
    {
        2
    }
    #[cfg(not(any(target_os = "android", target_os = "ios")))]
    {
        3
    }
}

/// A pooled connection handle. It derefs to `&Connection` so existing
/// `conn.execute(...)` / `conn.prepare(...)` call sites work unchanged.
/// Dropping it returns the inner `Connection` to the pool. The `Connection`
/// itself is wrapped in `Option` so `Drop` can take it out without moving
/// out of `self`.
pub struct PooledConn {
    conn: Option<Connection>,
    release: mpsc::SyncSender<Connection>,
}

impl PooledConn {
    /// Return the connection to the pool early. After this, deref will panic
    /// (the connection is gone) — callers normally just let `PooledConn` drop.
    pub fn release(mut self) {
        if let Some(conn) = self.conn.take() {
            // Ignore send error — pool channel closed (pool destroyed).
            let _ = self.release.send(conn);
        }
    }
}

impl std::ops::Deref for PooledConn {
    type Target = Connection;
    fn deref(&self) -> &Connection {
        // SAFETY: `conn` is only cleared in `release()` / `Drop`, both of which
        // consume `self` (by value or &mut). While a live `&PooledConn` exists,
        // `conn` is always `Some`.
        self.conn.as_ref().expect("PooledConn used after release")
    }
}

// On drop, hand the connection back to the pool. Using `Option::take` avoids
// "cannot move out of type implementing Drop" — we move the inner value, not self.
impl Drop for PooledConn {
    fn drop(&mut self) {
        if let Some(conn) = self.conn.take() {
            // If the receiver is dead (pool destroyed) the connection is closed
            // by being dropped here — that's the correct behavior.
            let _ = self.release.send(conn);
        }
    }
}

// The receiver is guarded by a Mutex so multiple threads can call `acquire()`
// concurrently against one pool (held behind an `Arc` in `MemoryStore`).
// Only one caller borrows a connection at a time — the connection is only
// returned to the channel on drop.
struct Rx(std::sync::Mutex<mpsc::Receiver<Connection>>);

pub struct ConnPoolInner {
    tx: mpsc::SyncSender<Connection>,
    rx: Rx,
}

impl ConnPoolInner {
    /// Create a new pool with `size` independent connections, all opened
    /// against `db_path` with WAL mode, busy_timeout, and synchronous=NORMAL.
    pub fn new(db_path: &str) -> Result<Self> {
        let size = pool_size();
        let (tx, rx) = mpsc::sync_channel::<Connection>(size);

        for _ in 0..size {
            let conn = open_connection(db_path)?;
            // Pre-fill the pool. send() on a sync_channel with capacity `size`
            // never blocks here because we send exactly `size` items.
            let _ = tx.send(conn);
        }

        Ok(Self {
            tx,
            rx: Rx(std::sync::Mutex::new(rx)),
        })
    }

    /// Borrow a connection from the pool. Blocks until one is available
    /// (should be instant with correct sizing). The caller holds it until
    /// the returned `PooledConn` is dropped or `.release()`d.
    pub fn acquire(&self) -> Result<PooledConn> {
        let conn =
            self.rx.0.lock().unwrap().recv().map_err(|_| {
                anyhow::anyhow!("ConnPool: all connections lost (pool channel closed)")
            })?;
        Ok(PooledConn {
            conn: Some(conn),
            release: self.tx.clone(),
        })
    }
}

// Re-export under the historical name `ConnPool` so store/mod.rs is unchanged.
pub use ConnPoolInner as ConnPool;

/// Create a standalone connection (not pooled) for use by a background
/// worker that needs its own dedicated connection — e.g. the store-embed
/// thread. This connection has the same WAL/busy_timeout settings but
/// is not returned to any pool on drop.
pub fn open_standalone(db_path: &str) -> Result<Connection> {
    open_connection(db_path)
}

/// Open a single connection with AURA's durability settings:
///   - WAL mode (concurrent readers + one writer, crash-safe)
///   - busy_timeout 5000ms (retry on lock for up to 5s instead of failing)
///   - synchronous=NORMAL (WAL + NORMAL = safe enough, much faster than EXTRA)
fn open_connection(db_path: &str) -> Result<Connection> {
    let conn = Connection::open(db_path)?;

    // WAL mode: readers don't block the writer. Crash-safe on kill/SIGKILL.
    conn.execute_batch("PRAGMA journal_mode=WAL;")?;
    // Retry up to 5s if another thread holds the lock.
    conn.execute_batch("PRAGMA busy_timeout=5000;")?;
    // WAL + NORMAL is the sweet spot: fsync on each commit but no extra
    // fsync after every write — fast enough for companion-grade latency.
    conn.execute_batch("PRAGMA synchronous=NORMAL;")?;
    // Larger cache keeps hot rows/indices in memory (fewer disk reads).
    conn.execute_batch("PRAGMA cache_size=-2000;")?; // ~2MB

    Ok(conn)
}

/// Open a **read-only** connection to `db_path`.
///
/// This is used by the notebook/query fns that used to round-trip through the
/// single engine worker channel (`api/memory.rs`). Those calls timed out (2s
/// `recv_timeout`) whenever the worker was busy generating, so the notebook
/// appeared empty mid-conversation. A direct read-only WAL connection can read
/// concurrently with the writer — WAL readers never block and are never blocked
/// — so the notebook always populates, regardless of what the engine is doing.
///
/// We force `query_only=ON` as a second line of defense so even a buggy caller
/// can't accidentally mutate the DB through this handle. Returns an error if the
/// DB file does not exist yet (caller falls back to the worker path).
pub fn open_readonly(db_path: &str) -> Result<Connection> {
    // SQLITE_OPEN_READ_ONLY requires the file to exist; Surface a clear error.
    if !std::path::Path::new(db_path).exists() {
        return Err(anyhow::anyhow!(
            "open_readonly: DB does not exist yet at {db_path}"
        ));
    }
    let conn = Connection::open_with_flags(
        db_path,
        OpenFlags::SQLITE_OPEN_READ_ONLY
            | OpenFlags::SQLITE_OPEN_NO_MUTEX
            | OpenFlags::SQLITE_OPEN_URI,
    )?;
    // Belt-and-suspenders: this connection may only read.
    let _ = conn.execute_batch("PRAGMA query_only=ON; PRAGMA busy_timeout=2000;");
    Ok(conn)
}

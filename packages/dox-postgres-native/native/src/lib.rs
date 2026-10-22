//! Native Postgres driver for Dart (dox_postgres_native).
//!
//! Rust owns the database connections (tokio-postgres, deadpool-postgres).
//! Dart sends queries in batches with one leaf FFI call (`dpg_submit`).
//! Rust runs them on a small tokio runtime and posts the results back in
//! batches to a Dart `ReceivePort` with `Dart_PostCObject`.
//!
//! Values stay in the Postgres binary format. Dart decodes them, the same
//! way the `postgres` Dart package does.
//!
//! Request record (little endian, 32 byte head): u64 id, u64 pool,
//! u64 tx (0: no transaction), u8 kind (0 query, 1 begin, 2 commit,
//! 3 rollback), u8 reserved, u16 param count, u32 sql length. Then the sql,
//! then per param: u32 type oid (0: let the server pick), u8 format
//! (0 text, 1 binary), i32 length (-1: NULL), bytes.
//!
//! Result record (13 byte head): u64 id, u8 status, u32 body length.
//! - status 0 (rows): u16 column count, per column u32 type oid, u16 name
//!   length, name. Then u32 row count, per value i32 length (-1: NULL), bytes.
//! - status 1 (server error): u8 field count, per field u8 code (the
//!   Postgres error field code, eg. b'C'), u32 length, text.
//! - status 2 (other error): the message.
//! - status 3 (transaction started): u64 transaction id.
use std::collections::HashMap;
use std::ffi::{CStr, c_char, c_int, c_void};
use std::str::FromStr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

use bytes::BytesMut;
use deadpool_postgres::{Manager, ManagerConfig, Object, Pool, RecyclingMethod};
use tokio::runtime::Handle;
use tokio::sync::mpsc;
use tokio_postgres::error::{ErrorPosition, SqlState};
use tokio_postgres::types::Format;
use tokio_postgres::types::{FromSql, IsNull, Kind, ToSql, Type, to_sql_checked};
use tokio_postgres::{NoTls, Row, Statement};

/// Bump when the FFI functions or the record layout change.
const ABI_VERSION: i32 = 1;
const REQ_HEAD: usize = 32;
const RES_HEAD: usize = 13;
/// Statements kept per connection. Over this, the cache is cleared.
/// ponytail: a simple clear, an LRU when apps use many different queries.
const CACHE_MAX: usize = 512;

// ---- Dart API DL -------------------------------------------------------
// `NativeApi.initializeApiDLData` points to this table. We only need
// `Dart_PostCObject`, so we read it here instead of compiling dart_api_dl.c.

#[repr(C)]
struct ApiEntry {
    name: *const c_char,
    function: *const c_void,
}

#[repr(C)]
struct DartApi {
    major: c_int,
    minor: c_int,
    functions: *const ApiEntry,
}

/// `Dart_CObject` for a `kTypedData` (Uint8) value. 64-bit layout.
#[repr(C)]
struct DartCObject {
    ty: i32,
    _pad: i32,
    td_type: i32,
    _pad2: i32,
    length: isize,
    values: *const u8,
    _rest: [u64; 2],
}

type PostFn = unsafe extern "C" fn(i64, *mut DartCObject) -> bool;
static POST: OnceLock<PostFn> = OnceLock::new();

/// Posts bytes to a Dart port. Dart copies them. False when the port is closed.
fn post(port: i64, data: &[u8]) -> bool {
    let Some(f) = POST.get() else { return false };
    let mut obj = DartCObject {
        ty: 7, // Dart_CObject_kTypedData
        _pad: 0,
        td_type: 2, // Dart_TypedData_kUint8
        _pad2: 0,
        length: data.len() as isize,
        values: data.as_ptr(),
        _rest: [0; 2],
    };
    unsafe { f(port, &mut obj) }
}

// ---- runtime and handles -----------------------------------------------

static RUNTIME: OnceLock<Handle> = OnceLock::new();

/// The runtime of the whole process. The first `dpg_connect` picks its kind:
/// `threads` 0 is one `current_thread` runtime on its own thread, more is a
/// multi-thread runtime with that many workers.
fn runtime(threads: usize) -> &'static Handle {
    RUNTIME.get_or_init(|| {
        if threads == 0 {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("runtime");
            let handle = rt.handle().clone();
            std::thread::Builder::new()
                .name("dox-pg".into())
                .spawn(move || rt.block_on(std::future::pending::<()>()))
                .expect("thread");
            handle
        } else {
            let rt = tokio::runtime::Builder::new_multi_thread()
                .worker_threads(threads)
                .thread_name("dox-pg")
                .enable_all()
                .build()
                .expect("runtime");
            let handle = rt.handle().clone();
            std::mem::forget(rt); // lives as long as the process
            handle
        }
    })
}

/// Handles given to Dart. A closed or unknown handle is not found, so a
/// late call from Dart can not touch freed memory.
struct Registry<T> {
    next: u64,
    map: HashMap<u64, T>,
}

impl<T: Clone> Registry<T> {
    fn new() -> Self {
        Registry {
            next: 0,
            map: HashMap::new(),
        }
    }
    fn insert(&mut self, value: T) -> u64 {
        self.next += 1;
        self.map.insert(self.next, value);
        self.next
    }
    fn get(&self, key: u64) -> Option<T> {
        self.map.get(&key).cloned()
    }
}

static POOLS: Mutex<Option<Registry<Pool>>> = Mutex::new(None);
static SINKS: Mutex<Option<Registry<Arc<Sink>>>> = Mutex::new(None);
static TXS: Mutex<Option<Registry<mpsc::UnboundedSender<Job>>>> = Mutex::new(None);

fn with<T: Clone, R>(reg: &Mutex<Option<Registry<T>>>, f: impl FnOnce(&mut Registry<T>) -> R) -> R {
    let mut guard = reg.lock().unwrap();
    f(guard.get_or_insert_with(Registry::new))
}

// ---- results to Dart ---------------------------------------------------

/// Results of one Dart isolate. Results that are ready in the same runtime
/// tick go to Dart in one post.
struct Sink {
    port: i64,
    buf: Mutex<Vec<u8>>,
    queued: AtomicBool,
}

impl Sink {
    fn push(self: &Arc<Self>, record: &[u8]) {
        let mut buf = self.buf.lock().unwrap();
        buf.extend_from_slice(record);
        if !self.queued.swap(true, Ordering::AcqRel) {
            let sink = self.clone();
            RUNTIME.get().expect("runtime").spawn(async move {
                // let the other tasks that are ready add their results first
                tokio::task::yield_now().await;
                sink.flush();
            });
        }
    }

    fn flush(&self) {
        let out = {
            let mut buf = self.buf.lock().unwrap();
            self.queued.store(false, Ordering::Release);
            std::mem::take(&mut *buf)
        };
        // false: the isolate is gone. Nobody waits for these results.
        post(self.port, &out);
    }
}

fn head(out: &mut Vec<u8>, id: u64, status: u8) {
    out.extend_from_slice(&id.to_le_bytes());
    out.push(status);
    out.extend_from_slice(&[0; 4]);
}

/// Writes the body length into the head.
fn done(mut out: Vec<u8>) -> Vec<u8> {
    let len = (out.len() - RES_HEAD) as u32;
    out[9..13].copy_from_slice(&len.to_le_bytes());
    out
}

fn message(id: u64, text: &str) -> Vec<u8> {
    let mut out = Vec::with_capacity(RES_HEAD + text.len());
    head(&mut out, id, 2);
    out.extend_from_slice(text.as_bytes());
    done(out)
}

fn error(id: u64, e: &tokio_postgres::Error) -> Vec<u8> {
    let Some(db) = e.as_db_error() else {
        return message(id, &e.to_string());
    };
    let mut out = Vec::with_capacity(256);
    head(&mut out, id, 1);
    let line = db.line().map(|l| l.to_string());
    let severity = db.parsed_severity().map(|s| s.to_string());
    let (position, internal, query) = match db.position() {
        Some(ErrorPosition::Original(p)) => (Some(p.to_string()), None, None),
        Some(ErrorPosition::Internal { position, query }) => {
            (None, Some(position.to_string()), Some(query.as_str()))
        }
        None => (None, None, None),
    };
    let fields: [(u8, Option<&str>); 18] = [
        (b'S', Some(db.severity())),
        (b'V', severity.as_deref()),
        (b'C', Some(db.code().code())),
        (b'M', Some(db.message())),
        (b'D', db.detail()),
        (b'H', db.hint()),
        (b'P', position.as_deref()),
        (b'p', internal.as_deref()),
        (b'q', query),
        (b'W', db.where_()),
        (b's', db.schema()),
        (b't', db.table()),
        (b'c', db.column()),
        (b'd', db.datatype()),
        (b'n', db.constraint()),
        (b'F', db.file()),
        (b'L', line.as_deref()),
        (b'R', db.routine()),
    ];
    let count_at = out.len();
    out.push(0);
    let mut count = 0u8;
    for (code, value) in fields {
        let Some(value) = value else { continue };
        out.push(code);
        out.extend_from_slice(&(value.len() as u32).to_le_bytes());
        out.extend_from_slice(value.as_bytes());
        count += 1;
    }
    out[count_at] = count;
    done(out)
}

fn pool_error(id: u64, e: deadpool_postgres::PoolError) -> Vec<u8> {
    match e {
        deadpool_postgres::PoolError::Backend(e) => error(id, &e),
        e => message(id, &e.to_string()),
    }
}

/// Any column as its raw bytes (binary format).
struct Raw<'a>(Option<&'a [u8]>);

impl<'a> FromSql<'a> for Raw<'a> {
    fn from_sql(_: &Type, raw: &'a [u8]) -> Result<Self, Box<dyn std::error::Error + Sync + Send>> {
        Ok(Raw(Some(raw)))
    }
    fn from_sql_null(_: &Type) -> Result<Self, Box<dyn std::error::Error + Sync + Send>> {
        Ok(Raw(None))
    }
    fn accepts(_: &Type) -> bool {
        true
    }
}

fn rows(id: u64, stmt: &Statement, rows: &[Row]) -> Vec<u8> {
    let cols = stmt.columns();
    let mut out = Vec::with_capacity(64 + cols.len() * (16 + rows.len() * 16));
    head(&mut out, id, 0);
    out.extend_from_slice(&(cols.len() as u16).to_le_bytes());
    for c in cols {
        out.extend_from_slice(&c.type_().oid().to_le_bytes());
        out.extend_from_slice(&(c.name().len() as u16).to_le_bytes());
        out.extend_from_slice(c.name().as_bytes());
    }
    out.extend_from_slice(&(rows.len() as u32).to_le_bytes());
    for row in rows {
        for i in 0..cols.len() {
            match row.try_get::<_, Raw>(i).map(|r| r.0) {
                Ok(Some(v)) => {
                    out.extend_from_slice(&(v.len() as i32).to_le_bytes());
                    out.extend_from_slice(v);
                }
                _ => out.extend_from_slice(&(-1i32).to_le_bytes()),
            }
        }
    }
    done(out)
}

// ---- queries -----------------------------------------------------------

/// A parameter, already encoded by Dart.
struct Param {
    oid: u32,
    binary: bool,
    data: Option<Vec<u8>>,
}

impl std::fmt::Debug for Param {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Param({})", self.oid)
    }
}

impl ToSql for Param {
    fn to_sql(
        &self,
        _: &Type,
        out: &mut BytesMut,
    ) -> Result<IsNull, Box<dyn std::error::Error + Sync + Send>> {
        match &self.data {
            None => Ok(IsNull::Yes),
            Some(d) => {
                out.extend_from_slice(d);
                Ok(IsNull::No)
            }
        }
    }
    fn accepts(_: &Type) -> bool {
        true
    }
    fn encode_format(&self, _: &Type) -> Format {
        if self.binary {
            Format::Binary
        } else {
            Format::Text
        }
    }
    to_sql_checked!();
}

/// oid 0: the server picks the type, like an untyped `postgres` parameter.
fn param_type(oid: u32) -> Type {
    Type::from_oid(oid)
        .unwrap_or_else(|| Type::new(String::new(), oid, Kind::Pseudo, String::new()))
}

/// The plan of a cached statement is out of date (eg. after ALTER TABLE).
fn stale(e: &tokio_postgres::Error) -> bool {
    e.code() == Some(&SqlState::FEATURE_NOT_SUPPORTED)
        || e.code() == Some(&SqlState::INVALID_SQL_STATEMENT_NAME)
}

async fn query(client: &Object, id: u64, sql: &str, params: &[Param]) -> Vec<u8> {
    let types: Vec<Type> = if params.iter().any(|p| p.oid != 0) {
        params.iter().map(|p| param_type(p.oid)).collect()
    } else {
        Vec::new()
    };
    let refs: Vec<&(dyn ToSql + Sync)> = params.iter().map(|p| p as _).collect();
    if client.statement_cache.size() > CACHE_MAX {
        client.statement_cache.clear();
    }
    let mut retried = false;
    loop {
        let stmt = if types.is_empty() {
            client.prepare_cached(sql).await
        } else {
            client.prepare_typed_cached(sql, &types).await
        };
        let stmt = match stmt {
            Ok(s) => s,
            Err(e) => return error(id, &e),
        };
        match client.query(&stmt, &refs).await {
            Ok(r) => return rows(id, &stmt, &r),
            Err(e) if !retried && stale(&e) => {
                client.statement_cache.remove(sql, &types);
                retried = true;
            }
            Err(e) => return error(id, &e),
        }
    }
}

/// Work for the task that owns the connection of one transaction.
enum Job {
    Query {
        id: u64,
        sql: String,
        params: Vec<Param>,
        sink: Arc<Sink>,
    },
    End {
        id: u64,
        commit: bool,
        sink: Arc<Sink>,
    },
}

/// Starts a transaction on one connection. Its queries run one after the
/// other on that connection, in the order Dart sent them.
async fn begin(id: u64, pool: Pool, sink: Arc<Sink>) {
    let client = match pool.get().await {
        Ok(c) => c,
        Err(e) => return sink.push(&pool_error(id, e)),
    };
    if let Err(e) = client.batch_execute("BEGIN").await {
        return sink.push(&error(id, &e));
    }
    let (tx, mut rx) = mpsc::unbounded_channel();
    let key = with(&TXS, |r| r.insert(tx));
    let mut out = Vec::with_capacity(RES_HEAD + 8);
    head(&mut out, id, 3);
    out.extend_from_slice(&key.to_le_bytes());
    sink.push(&done(out));
    // ponytail: a transaction that Dart never ends keeps its connection.
    while let Some(job) = rx.recv().await {
        match job {
            Job::Query {
                id,
                sql,
                params,
                sink,
            } => sink.push(&query(&client, id, &sql, &params).await),
            Job::End { id, commit, sink } => {
                with(&TXS, |r| r.map.remove(&key));
                let sql = if commit { "COMMIT" } else { "ROLLBACK" };
                let out = match client.batch_execute(sql).await {
                    Ok(()) => message_ok(id),
                    Err(e) => error(id, &e),
                };
                return sink.push(&out);
            }
        }
    }
}

/// An empty result (no columns, no rows).
fn message_ok(id: u64) -> Vec<u8> {
    let mut out = Vec::with_capacity(RES_HEAD + 6);
    head(&mut out, id, 0);
    out.extend_from_slice(&[0; 6]);
    done(out)
}

fn rd16(b: &[u8], p: usize) -> usize {
    u16::from_le_bytes([b[p], b[p + 1]]) as usize
}

fn rd32(b: &[u8], p: usize) -> u32 {
    u32::from_le_bytes(b[p..p + 4].try_into().unwrap())
}

fn rd64(b: &[u8], p: usize) -> u64 {
    u64::from_le_bytes(b[p..p + 8].try_into().unwrap())
}

/// One request record. None when it is broken.
struct Request {
    id: u64,
    pool: u64,
    tx: u64,
    kind: u8,
    sql: String,
    params: Vec<Param>,
}

fn parse(b: &[u8], p: &mut usize) -> Option<Request> {
    let at = *p;
    if at + REQ_HEAD > b.len() {
        return None;
    }
    let count = rd16(b, at + 26);
    let sql_len = rd32(b, at + 28) as usize;
    let mut q = at + REQ_HEAD;
    let sql = String::from_utf8_lossy(b.get(q..q + sql_len)?).into_owned();
    q += sql_len;
    let mut params = Vec::with_capacity(count);
    for _ in 0..count {
        if q + 9 > b.len() {
            return None;
        }
        let oid = rd32(b, q);
        let binary = b[q + 4] == 1;
        let len = rd32(b, q + 5) as i32;
        q += 9;
        let data = if len < 0 {
            None
        } else {
            let d = b.get(q..q + len as usize)?.to_vec();
            q += len as usize;
            Some(d)
        };
        params.push(Param { oid, binary, data });
    }
    *p = q;
    Some(Request {
        id: rd64(b, at),
        pool: rd64(b, at + 8),
        tx: rd64(b, at + 16),
        kind: b[at + 24],
        sql,
        params,
    })
}

fn run(req: Request, sink: Arc<Sink>, rt: &Handle) {
    let Request {
        id,
        pool,
        tx,
        kind,
        sql,
        params,
    } = req;
    if tx != 0 {
        let Some(sender) = with(&TXS, |r| r.get(tx)) else {
            return sink.push(&message(id, "the transaction is closed"));
        };
        let job = match kind {
            0 => Job::Query {
                id,
                sql,
                params,
                sink: sink.clone(),
            },
            _ => Job::End {
                id,
                commit: kind == 2,
                sink: sink.clone(),
            },
        };
        if sender.send(job).is_err() {
            sink.push(&message(id, "the transaction is closed"));
        }
        return;
    }
    let Some(pool) = with(&POOLS, |r| r.get(pool)) else {
        return sink.push(&message(id, "the pool is closed"));
    };
    match kind {
        0 => {
            rt.spawn(async move {
                let out = match pool.get().await {
                    Ok(client) => query(&client, id, &sql, &params).await,
                    Err(e) => pool_error(id, e),
                };
                sink.push(&out);
            });
        }
        1 => {
            rt.spawn(begin(id, pool, sink));
        }
        _ => sink.push(&message(id, "no transaction to end")),
    }
}

// ---- FFI ---------------------------------------------------------------

/// ABI version of this library. Dart checks it at load.
#[unsafe(no_mangle)]
pub extern "C" fn dpg_version() -> i32 {
    ABI_VERSION
}

/// Reads `Dart_PostCObject` from `NativeApi.initializeApiDLData`.
/// Returns 0 on success.
///
/// # Safety
/// `data` must be `NativeApi.initializeApiDLData`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dpg_init(data: *mut c_void) -> i32 {
    if data.is_null() {
        return -1;
    }
    let api = unsafe { &*(data as *const DartApi) };
    if api.major != 2 {
        return -2; // DART_API_DL_MAJOR_VERSION
    }
    let mut entry = api.functions;
    unsafe {
        while !(*entry).name.is_null() {
            if CStr::from_ptr((*entry).name).to_bytes() == b"Dart_PostCObject" {
                let f: PostFn = std::mem::transmute((*entry).function);
                let _ = POST.set(f);
                return 0;
            }
            entry = entry.add(1);
        }
    }
    -3
}

/// Makes a pool from a libpq style config (`host=... user=...` or a
/// `postgres://` url). Connections open when they are needed.
/// Returns a pool handle (> 0), or -1 when the config is bad.
///
/// # Safety
/// `cfg` must point to `len` readable bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dpg_connect(cfg: *const u8, len: i64, max_size: i64, threads: i64) -> i64 {
    let cfg = unsafe { std::slice::from_raw_parts(cfg, len as usize) };
    let Ok(cfg) = std::str::from_utf8(cfg) else {
        return -1;
    };
    let Ok(pg) = tokio_postgres::Config::from_str(cfg) else {
        return -1;
    };
    let manager = Manager::from_config(
        pg,
        NoTls,
        ManagerConfig {
            recycling_method: RecyclingMethod::Fast,
        },
    );
    let Ok(pool) = Pool::builder(manager)
        .max_size(max_size.max(1) as usize)
        .build()
    else {
        return -1;
    };
    runtime(threads.max(0) as usize);
    with(&POOLS, |r| r.insert(pool)) as i64
}

/// Closes the pool. Running queries finish, new ones fail.
#[unsafe(no_mangle)]
pub extern "C" fn dpg_close(pool: i64) {
    if let Some(pool) = with(&POOLS, |r| r.map.remove(&(pool as u64))) {
        pool.close();
    }
}

/// Opens the result sink of one isolate. Results go to `send_port`.
#[unsafe(no_mangle)]
pub extern "C" fn dpg_open(send_port: i64) -> i64 {
    let sink = Arc::new(Sink {
        port: send_port,
        buf: Mutex::new(Vec::new()),
        queued: AtomicBool::new(false),
    });
    with(&SINKS, |r| r.insert(sink)) as i64
}

/// Closes a sink. Results that come later are dropped.
#[unsafe(no_mangle)]
pub extern "C" fn dpg_release(sink: i64) {
    with(&SINKS, |r| r.map.remove(&(sink as u64)));
}

/// Called from Dart (leaf call) with a batch of request records.
///
/// # Safety
/// `ptr` must point to `len` readable bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dpg_submit(sink: i64, ptr: *const u8, len: i64) {
    let Some(sink) = with(&SINKS, |r| r.get(sink as u64)) else {
        return;
    };
    let Some(rt) = RUNTIME.get() else { return };
    let b = unsafe { std::slice::from_raw_parts(ptr, len as usize) };
    let mut p = 0;
    while let Some(req) = parse(b, &mut p) {
        run(req, sink.clone(), rt);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request(id: u64, sql: &str, params: &[Option<&str>]) -> Vec<u8> {
        let mut b = Vec::new();
        b.extend_from_slice(&id.to_le_bytes());
        b.extend_from_slice(&7u64.to_le_bytes());
        b.extend_from_slice(&0u64.to_le_bytes());
        b.extend_from_slice(&[0, 0]);
        b.extend_from_slice(&(params.len() as u16).to_le_bytes());
        b.extend_from_slice(&(sql.len() as u32).to_le_bytes());
        b.extend_from_slice(sql.as_bytes());
        for p in params {
            b.extend_from_slice(&0u32.to_le_bytes());
            b.push(0);
            match p {
                None => b.extend_from_slice(&(-1i32).to_le_bytes()),
                Some(v) => {
                    b.extend_from_slice(&(v.len() as i32).to_le_bytes());
                    b.extend_from_slice(v.as_bytes());
                }
            }
        }
        b
    }

    #[test]
    fn parses_requests() {
        let mut b = request(1, "select $1, $2", &[Some("42"), None]);
        b.extend(request(2, "select 1", &[]));
        let mut p = 0;
        let a = parse(&b, &mut p).unwrap();
        assert_eq!((a.id, a.pool, a.kind), (1, 7, 0));
        assert_eq!(a.sql, "select $1, $2");
        assert_eq!(a.params[0].data.as_deref(), Some(&b"42"[..]));
        assert!(a.params[1].data.is_none());
        let c = parse(&b, &mut p).unwrap();
        assert_eq!((c.id, c.sql.as_str()), (2, "select 1"));
        assert!(parse(&b, &mut p).is_none());
        // a cut record is dropped
        let mut p = 0;
        assert!(parse(&b[..40], &mut p).is_none());
    }

    #[test]
    fn writes_the_body_length() {
        let out = message(9, "boom");
        assert_eq!(rd64(&out, 0), 9);
        assert_eq!(out[8], 2);
        assert_eq!(rd32(&out, 9), 4);
        assert_eq!(&out[13..], b"boom");
    }

    /// Needs Postgres (PG_URL, eg. postgres://postgres:postgres@localhost/postgres).
    #[tokio::test]
    async fn runs_a_query() {
        let Ok(url) = std::env::var("PG_URL") else {
            return;
        };
        let pg = tokio_postgres::Config::from_str(&url).unwrap();
        let manager = Manager::new(pg, NoTls);
        let pool = Pool::builder(manager).max_size(2).build().unwrap();
        let client = pool.get().await.unwrap();
        let p = [Param {
            oid: 0,
            binary: false,
            data: Some(b"41".to_vec()),
        }];
        let out = query(&client, 5, "select $1::int8 + 1 as n", &p).await;
        assert_eq!(out[8], 0, "{:?}", String::from_utf8_lossy(&out));
        // 1 column int8 named n, 1 row with 8 bytes
        assert_eq!(rd16(&out, 13), 1);
        assert_eq!(rd32(&out, 15), 20);
        let at = out.len() - 8;
        assert_eq!(i64::from_be_bytes(out[at..].try_into().unwrap()), 42);
        let bad = query(&client, 6, "select * from nope_missing", &[]).await;
        assert_eq!(bad[8], 1);
    }
}

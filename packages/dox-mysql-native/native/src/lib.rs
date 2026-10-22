//! Native MySQL and MariaDB driver for Dart (dox_mysql_native).
//!
//! Rust (mysql_async on tokio) owns the connections. Dart only encodes
//! requests and decodes results.
//!
//! - One tokio runtime per process. Pools live in a registry, so all
//!   isolates can share one pool (same URL = same pool).
//! - Each isolate opens a client with its `ReceivePort`. Requests are sent
//!   in batches with one leaf FFI call (`dox_mysql_submit`). Results are
//!   added to a batch and posted to the port with `Dart_PostCObject`.
//!   Results that finish at about the same time share one post.
//! - mysql_async keeps a prepared statement cache per connection.
//!
//! Request record (little endian, 32 byte head): u64 id, u64 pool, u64 tx,
//! u8 op, 3 bytes reserved, u32 sql_len. Then u32 param count, sql, params.
//! A param is a u8 tag and a value: 0 null, 1 i64, 2 f64,
//! 3 text (u32 len + utf8), 4 bytes (u32 len + bytes).
//!
//! Result record (16 byte head): u64 id, u8 status (0 ok, 1 error),
//! 3 bytes reserved, u32 body_len. Then the body.
//! - ok: u64 affected rows, u64 insert id (the tx handle for `begin`),
//!   u32 column count, u32 row count, the names (u16 len + utf8), then each
//!   cell as a u8 tag and a value: 0 null, 1 i64, 2 f64, 3 text,
//!   4 bytes, 5 date (i64 microseconds since epoch, UTC), 6 bool (u8),
//!   7 json text, 8 long text (TEXT columns, MariaDB keeps JSON there).
//!   Text, bytes and json are a u32 len and the bytes.
//! - error: u16 server error code (0 for a client error), u8 kind
//!   (0 server, 1 client), 5 bytes sqlstate, then the message (utf8).
use std::ffi::{CStr, c_char, c_int, c_void};
use std::sync::{Arc, Mutex, OnceLock};

use mysql_async::consts::{ColumnFlags, ColumnType};
use mysql_async::prelude::*;
use mysql_async::{Column, Conn, Opts, Params, Pool, QueryResult, Value};
use slab::Slab;
use tokio::runtime::Runtime;

/// Bump when the FFI functions or the record layout change.
const ABI_VERSION: i32 = 1;

const OP_QUERY: u8 = 0;
const OP_EXECUTE: u8 = 1;
const OP_BEGIN: u8 = 2;
const OP_COMMIT: u8 = 3;
const OP_ROLLBACK: u8 = 4;

const T_NULL: u8 = 0;
const T_INT: u8 = 1;
const T_DOUBLE: u8 = 2;
const T_TEXT: u8 = 3;
const T_BYTES: u8 = 4;
const T_DATE: u8 = 5;
const T_BOOL: u8 = 6;
const T_JSON: u8 = 7;
const T_LONG_TEXT: u8 = 8;

/// charset id of binary data (BLOB, VARBINARY, BINARY)
const BINARY: u16 = 63;

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

// ---- registries --------------------------------------------------------

fn runtime() -> &'static Runtime {
    static RT: OnceLock<Runtime> = OnceLock::new();
    RT.get_or_init(|| {
        let threads = std::env::var("DOX_MYSQL_THREADS")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(1);
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(threads)
            .thread_name("dox_mysql")
            .enable_all()
            .build()
            .expect("tokio runtime")
    })
}

struct PoolEntry {
    url: String,
    pool: Pool,
    users: usize,
}

/// One isolate. Results wait in `out` until the next post.
struct Client {
    port: i64,
    out: Mutex<(Vec<u8>, bool)>,
}

/// A transaction: one connection, taken from the pool until commit or
/// rollback. The lock runs its queries one by one.
type Tx = Arc<tokio::sync::Mutex<Conn>>;

static POOLS: Mutex<Slab<PoolEntry>> = Mutex::new(Slab::new());
static CLIENTS: Mutex<Slab<Arc<Client>>> = Mutex::new(Slab::new());
static TXS: Mutex<Slab<Tx>> = Mutex::new(Slab::new());

/// handles are slab keys + 1, so 0 is never a handle
fn get<T: Clone>(slab: &Mutex<Slab<T>>, handle: u64) -> Option<T> {
    let key = handle.checked_sub(1)? as usize;
    slab.lock().unwrap().get(key).cloned()
}

fn pool_of(handle: u64) -> Option<Pool> {
    let key = handle.checked_sub(1)? as usize;
    POOLS.lock().unwrap().get(key).map(|e| e.pool.clone())
}

// ---- requests ----------------------------------------------------------

struct Request {
    id: u64,
    pool: u64,
    tx: u64,
    op: u8,
    sql: String,
    params: Vec<Value>,
}

/// Reads little endian values. Every read checks the length.
struct Reader<'a>(&'a [u8]);

impl<'a> Reader<'a> {
    fn take(&mut self, n: usize) -> Option<&'a [u8]> {
        if self.0.len() < n {
            return None;
        }
        let (a, b) = self.0.split_at(n);
        self.0 = b;
        Some(a)
    }
    fn u8(&mut self) -> Option<u8> {
        Some(self.take(1)?[0])
    }
    fn u32(&mut self) -> Option<u32> {
        Some(u32::from_le_bytes(self.take(4)?.try_into().ok()?))
    }
    fn u64(&mut self) -> Option<u64> {
        Some(u64::from_le_bytes(self.take(8)?.try_into().ok()?))
    }
}

fn read_request(r: &mut Reader) -> Option<Request> {
    let id = r.u64()?;
    let pool = r.u64()?;
    let tx = r.u64()?;
    let op = r.u8()?;
    r.take(3)?;
    let sql_len = r.u32()? as usize;
    let count = r.u32()? as usize;
    let sql = String::from_utf8_lossy(r.take(sql_len)?).into_owned();
    let mut params = Vec::with_capacity(count.min(1024));
    for _ in 0..count {
        params.push(match r.u8()? {
            T_NULL => Value::NULL,
            T_INT => Value::Int(r.u64()? as i64),
            T_DOUBLE => Value::Double(f64::from_bits(r.u64()?)),
            _ => {
                let len = r.u32()? as usize;
                Value::Bytes(r.take(len)?.to_vec())
            }
        });
    }
    Some(Request {
        id,
        pool,
        tx,
        op,
        sql,
        params,
    })
}

enum Fail {
    Server(mysql_async::ServerError),
    Client(String),
}

impl From<mysql_async::Error> for Fail {
    fn from(e: mysql_async::Error) -> Self {
        match e {
            mysql_async::Error::Server(s) => Fail::Server(s),
            other => Fail::Client(other.to_string()),
        }
    }
}

async fn run(req: Request) -> Result<Vec<u8>, Fail> {
    match req.op {
        OP_BEGIN => {
            let pool = pool_of(req.pool).ok_or(Fail::Client("pool is closed".into()))?;
            let mut conn = pool.get_conn().await?;
            conn.query_drop("START TRANSACTION").await?;
            let key = TXS
                .lock()
                .unwrap()
                .insert(Arc::new(tokio::sync::Mutex::new(conn)));
            Ok(ok_head(0, key as u64 + 1))
        }
        OP_COMMIT | OP_ROLLBACK => {
            let key = req.tx.wrapping_sub(1) as usize;
            let tx = TXS
                .lock()
                .unwrap()
                .try_remove(key)
                .ok_or(Fail::Client("transaction is closed".into()))?;
            let mut conn = tx.lock().await;
            let sql = if req.op == OP_COMMIT {
                "COMMIT"
            } else {
                "ROLLBACK"
            };
            conn.query_drop(sql).await?;
            Ok(ok_head(0, 0))
        }
        OP_QUERY | OP_EXECUTE => {
            let rows = req.op == OP_QUERY;
            if req.tx != 0 {
                let tx = get(&TXS, req.tx).ok_or(Fail::Client("transaction is closed".into()))?;
                let mut conn = tx.lock().await;
                exec(&mut conn, &req.sql, req.params, rows).await
            } else {
                let pool = pool_of(req.pool).ok_or(Fail::Client("pool is closed".into()))?;
                let mut conn = pool.get_conn().await?;
                exec(&mut conn, &req.sql, req.params, rows).await
            }
        }
        op => Err(Fail::Client(format!("unknown op {op}"))),
    }
}

/// No params: text protocol, one round trip. Params: prepared statement,
/// cached per connection by mysql_async.
async fn exec(conn: &mut Conn, sql: &str, params: Vec<Value>, rows: bool) -> Result<Vec<u8>, Fail> {
    if params.is_empty() {
        let res = conn.query_iter(sql).await?;
        read(res, rows).await
    } else {
        let res = conn.exec_iter(sql, Params::Positional(params)).await?;
        read(res, rows).await
    }
}

fn ok_head(affected: u64, insert_id: u64) -> Vec<u8> {
    let mut out = Vec::with_capacity(256);
    out.extend_from_slice(&affected.to_le_bytes());
    out.extend_from_slice(&insert_id.to_le_bytes());
    out.extend_from_slice(&0u32.to_le_bytes());
    out.extend_from_slice(&0u32.to_le_bytes());
    out
}

/// Encodes the first result set. More result sets (multi statements) are
/// read and dropped.
async fn read<P: Protocol>(mut res: QueryResult<'_, '_, P>, rows: bool) -> Result<Vec<u8>, Fail> {
    let cols: Arc<[Column]> = res.columns().unwrap_or_else(|| Arc::from(Vec::new()));
    let mut out = ok_head(0, 0);
    let kinds: Vec<Kind> = cols.iter().map(kind_of).collect();
    let mut count: u32 = 0;
    if rows {
        out[16..20].copy_from_slice(&(cols.len() as u32).to_le_bytes());
        for c in cols.iter() {
            let name = c.name_ref();
            out.extend_from_slice(&(name.len() as u16).to_le_bytes());
            out.extend_from_slice(name);
        }
    }
    while let Some(row) = res.next().await? {
        if rows {
            for (value, kind) in row.unwrap().into_iter().zip(&kinds) {
                cell(&mut out, *kind, value);
            }
            count += 1;
        }
    }
    let affected = res.affected_rows();
    let insert_id = res.last_insert_id().unwrap_or(0);
    res.drop_result().await?;
    out[0..8].copy_from_slice(&affected.to_le_bytes());
    out[8..16].copy_from_slice(&insert_id.to_le_bytes());
    out[20..24].copy_from_slice(&count.to_le_bytes());
    Ok(out)
}

// ---- values ------------------------------------------------------------

/// What the Dart driver gets for a column. Same as the mysql_dart driver.
#[derive(Clone, Copy, PartialEq, Debug)]
enum Kind {
    Text,
    Bool,
    Int,
    Double,
    Date,
    Json,
    LongText,
    Bytes,
    Time,
}

fn kind_of(c: &Column) -> Kind {
    use ColumnType::*;
    let binary = c.character_set() == BINARY;
    match c.column_type() {
        // TINYINT(1), used by boolean()
        MYSQL_TYPE_TINY if c.column_length() == 1 => Kind::Bool,
        MYSQL_TYPE_TINY | MYSQL_TYPE_SHORT | MYSQL_TYPE_LONG | MYSQL_TYPE_LONGLONG
        | MYSQL_TYPE_INT24 | MYSQL_TYPE_YEAR => Kind::Int,
        MYSQL_TYPE_FLOAT | MYSQL_TYPE_DOUBLE | MYSQL_TYPE_DECIMAL | MYSQL_TYPE_NEWDECIMAL => {
            Kind::Double
        }
        MYSQL_TYPE_DATE
        | MYSQL_TYPE_NEWDATE
        | MYSQL_TYPE_DATETIME
        | MYSQL_TYPE_DATETIME2
        | MYSQL_TYPE_TIMESTAMP
        | MYSQL_TYPE_TIMESTAMP2 => Kind::Date,
        MYSQL_TYPE_TIME | MYSQL_TYPE_TIME2 => Kind::Time,
        MYSQL_TYPE_JSON => Kind::Json,
        MYSQL_TYPE_TINY_BLOB | MYSQL_TYPE_MEDIUM_BLOB | MYSQL_TYPE_LONG_BLOB | MYSQL_TYPE_BLOB => {
            if binary {
                Kind::Bytes
            } else {
                Kind::LongText
            }
        }
        MYSQL_TYPE_BIT | MYSQL_TYPE_GEOMETRY => Kind::Bytes,
        _ if binary && !c.flags().contains(ColumnFlags::ENUM_FLAG) => Kind::Bytes,
        _ => Kind::Text,
    }
}

fn put_bytes(out: &mut Vec<u8>, tag: u8, b: &[u8]) {
    out.push(tag);
    out.extend_from_slice(&(b.len() as u32).to_le_bytes());
    out.extend_from_slice(b);
}

fn put_int(out: &mut Vec<u8>, v: i64) {
    out.push(T_INT);
    out.extend_from_slice(&v.to_le_bytes());
}

fn put_double(out: &mut Vec<u8>, v: f64) {
    out.push(T_DOUBLE);
    out.extend_from_slice(&v.to_bits().to_le_bytes());
}

fn put_text(out: &mut Vec<u8>, s: &str) {
    put_bytes(out, T_TEXT, s.as_bytes());
}

fn cell(out: &mut Vec<u8>, kind: Kind, value: Value) {
    match (kind, value) {
        (_, Value::NULL) => out.push(T_NULL),
        (Kind::Bool, Value::Int(v)) => out.extend_from_slice(&[T_BOOL, (v != 0) as u8]),
        (Kind::Bool, Value::UInt(v)) => out.extend_from_slice(&[T_BOOL, (v != 0) as u8]),
        (Kind::Bool, Value::Bytes(b)) => out.extend_from_slice(&[T_BOOL, (b != b"0") as u8]),
        (_, Value::Int(v)) => put_int(out, v),
        (_, Value::UInt(v)) => match i64::try_from(v) {
            Ok(v) => put_int(out, v),
            Err(_) => put_text(out, &v.to_string()),
        },
        (_, Value::Float(v)) => put_double(out, f64::from(v)),
        (_, Value::Double(v)) => put_double(out, v),
        (_, Value::Date(y, mo, d, h, mi, s, us)) => date(out, y, mo, d, h, mi, s, us),
        (_, Value::Time(neg, days, h, m, s, us)) => {
            put_text(out, &time_text(neg, days, h, m, s, us))
        }
        (Kind::Int, Value::Bytes(b)) => {
            match std::str::from_utf8(&b).ok().and_then(|s| s.parse().ok()) {
                Some(v) => put_int(out, v),
                None => put_bytes(out, T_TEXT, &b),
            }
        }
        (Kind::Double, Value::Bytes(b)) => {
            match std::str::from_utf8(&b).ok().and_then(|s| s.parse().ok()) {
                Some(v) => put_double(out, v),
                None => put_bytes(out, T_TEXT, &b),
            }
        }
        (Kind::Date, Value::Bytes(b)) => match parse_date(&b) {
            Some((y, mo, d, h, mi, s, us)) => date(out, y, mo, d, h, mi, s, us),
            None => put_bytes(out, T_TEXT, &b),
        },
        (Kind::Json, Value::Bytes(b)) => put_bytes(out, T_JSON, &b),
        (Kind::LongText, Value::Bytes(b)) => put_bytes(out, T_LONG_TEXT, &b),
        (Kind::Bytes, Value::Bytes(b)) => put_bytes(out, T_BYTES, &b),
        (_, Value::Bytes(b)) => put_bytes(out, T_TEXT, &b),
    }
}

#[allow(clippy::too_many_arguments)]
fn date(out: &mut Vec<u8>, y: u16, mo: u8, d: u8, h: u8, mi: u8, s: u8, us: u32) {
    if mo == 0 || d == 0 {
        // a zero date like 0000-00-00 is not a DateTime, keep the text
        let text = format!("{y:04}-{mo:02}-{d:02} {h:02}:{mi:02}:{s:02}");
        return put_text(out, &text);
    }
    let days = days_from_civil(i64::from(y), i64::from(mo), i64::from(d));
    let secs = days * 86_400 + i64::from(h) * 3600 + i64::from(mi) * 60 + i64::from(s);
    out.push(T_DATE);
    out.extend_from_slice(&(secs * 1_000_000 + i64::from(us)).to_le_bytes());
}

/// days since 1970-01-01 (Howard Hinnant's algorithm)
fn days_from_civil(y: i64, m: i64, d: i64) -> i64 {
    let y = if m <= 2 { y - 1 } else { y };
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let mp = (m + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

type DateParts = (u16, u8, u8, u8, u8, u8, u32);

/// `YYYY-MM-DD`, `YYYY-MM-DD HH:MM:SS` and `YYYY-MM-DD HH:MM:SS.ffffff`
fn parse_date(b: &[u8]) -> Option<DateParts> {
    let s = std::str::from_utf8(b).ok()?;
    let num = |r: std::ops::Range<usize>| s.get(r)?.parse::<u32>().ok();
    let y = num(0..4)? as u16;
    let mo = num(5..7)? as u8;
    let d = num(8..10)? as u8;
    if s.len() == 10 {
        return Some((y, mo, d, 0, 0, 0, 0));
    }
    let h = num(11..13)? as u8;
    let mi = num(14..16)? as u8;
    let sec = num(17..19)? as u8;
    let mut us = 0;
    if let Some(frac) = s.get(20..).filter(|f| !f.is_empty()) {
        let digits = &frac[..frac.len().min(6)];
        us = digits.parse::<u32>().ok()? * 10u32.pow(6 - digits.len() as u32);
    }
    Some((y, mo, d, h, mi, sec, us))
}

fn time_text(neg: bool, days: u32, h: u8, m: u8, s: u8, us: u32) -> String {
    let sign = if neg { "-" } else { "" };
    let hours = days * 24 + u32::from(h);
    if us == 0 {
        format!("{sign}{hours:02}:{m:02}:{s:02}")
    } else {
        format!("{sign}{hours:02}:{m:02}:{s:02}.{us:06}")
    }
}

// ---- results back to Dart ----------------------------------------------

fn record(id: u64, result: Result<Vec<u8>, Fail>) -> Vec<u8> {
    let (status, body) = match result {
        Ok(body) => (0u8, body),
        Err(fail) => {
            let (code, kind, state, msg) = match fail {
                Fail::Server(e) => (e.code, 0u8, e.state, e.message),
                Fail::Client(msg) => (0, 1, "HY000".to_string(), msg),
            };
            let mut body = Vec::with_capacity(8 + msg.len());
            body.extend_from_slice(&code.to_le_bytes());
            body.push(kind);
            let mut st = [b' '; 5];
            for (d, c) in st.iter_mut().zip(state.bytes()) {
                *d = c;
            }
            body.extend_from_slice(&st);
            body.extend_from_slice(msg.as_bytes());
            (1, body)
        }
    };
    let mut out = Vec::with_capacity(16 + body.len());
    out.extend_from_slice(&id.to_le_bytes());
    out.extend_from_slice(&[status, 0, 0, 0]);
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(&body);
    out
}

impl Client {
    /// Adds a result. The first result of a batch posts the batch after
    /// one yield, so results that finish meanwhile go in the same post.
    async fn deliver(&self, rec: Vec<u8>) {
        let first = {
            let mut out = self.out.lock().unwrap();
            out.0.extend_from_slice(&rec);
            !std::mem::replace(&mut out.1, true)
        };
        if !first {
            return;
        }
        tokio::task::yield_now().await;
        let batch = {
            let mut out = self.out.lock().unwrap();
            out.1 = false;
            std::mem::take(&mut out.0)
        };
        post(self.port, &batch);
    }
}

// ---- FFI ---------------------------------------------------------------

/// ABI version of this library. Dart checks it at load.
#[unsafe(no_mangle)]
pub extern "C" fn dox_mysql_version() -> i32 {
    ABI_VERSION
}

/// Reads `Dart_PostCObject` from `NativeApi.initializeApiDLData`.
/// Returns 0 on success.
///
/// # Safety
/// `data` must be `NativeApi.initializeApiDLData`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dox_mysql_init(data: *mut c_void) -> i32 {
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

/// Opens a pool for a `mysql://` URL (see mysql_async `Opts::from_url`).
/// It connects lazily, on the first query. The same URL gives the same
/// pool, so isolates share it. Returns a handle (> 0), or -1 for a bad URL.
///
/// # Safety
/// `url` must point to `len` bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dox_mysql_connect(url: *const u8, len: i64) -> i64 {
    let bytes = unsafe { std::slice::from_raw_parts(url, len as usize) };
    let Ok(url) = std::str::from_utf8(bytes) else {
        return -1;
    };
    let mut pools = POOLS.lock().unwrap();
    if let Some((key, entry)) = pools.iter_mut().find(|(_, e)| e.url == url) {
        entry.users += 1;
        return key as i64 + 1;
    }
    let Ok(opts) = Opts::from_url(url) else {
        return -1;
    };
    // Pool::new spawns a task, so it needs the runtime
    let _guard = runtime().enter();
    let key = pools.insert(PoolEntry {
        url: url.to_string(),
        pool: Pool::new(opts),
        users: 1,
    });
    key as i64 + 1
}

/// Gives up one use of a pool. The last one closes its connections.
#[unsafe(no_mangle)]
pub extern "C" fn dox_mysql_close(handle: i64) {
    let Some(key) = (handle as u64).checked_sub(1) else {
        return;
    };
    let mut pools = POOLS.lock().unwrap();
    let Some(entry) = pools.get_mut(key as usize) else {
        return;
    };
    entry.users -= 1;
    if entry.users == 0 {
        let pool = pools.remove(key as usize).pool;
        runtime().spawn(async move {
            let _ = pool.disconnect().await;
        });
    }
}

/// Opens a client: results are posted to `send_port`. Returns a handle,
/// or -1 when `dox_mysql_init` did not run.
#[unsafe(no_mangle)]
pub extern "C" fn dox_mysql_client(send_port: i64) -> i64 {
    if POST.get().is_none() {
        return -1;
    }
    let client = Arc::new(Client {
        port: send_port,
        out: Mutex::new((Vec::new(), false)),
    });
    CLIENTS.lock().unwrap().insert(client) as i64 + 1
}

/// Closes a client. Results that come later are dropped.
#[unsafe(no_mangle)]
pub extern "C" fn dox_mysql_client_close(handle: i64) {
    if let Some(key) = (handle as u64).checked_sub(1) {
        CLIENTS.lock().unwrap().try_remove(key as usize);
    }
}

/// Runs a batch of request records. Each result is posted to the port of
/// the client. Copies the bytes, so Dart can reuse its buffer.
///
/// # Safety
/// `ptr` must point to `len` bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dox_mysql_submit(client: i64, ptr: *const u8, len: i64) {
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len as usize) };
    let Some(client) = get(&CLIENTS, client as u64) else {
        return;
    };
    let mut r = Reader(bytes);
    let rt = runtime();
    while let Some(req) = read_request(&mut r) {
        let client = client.clone();
        rt.spawn(async move {
            let id = req.id;
            let result = run(req).await;
            client.deliver(record(id, result)).await;
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn civil_days() {
        assert_eq!(days_from_civil(1970, 1, 1), 0);
        assert_eq!(days_from_civil(2000, 3, 1), 11_017);
        assert_eq!(days_from_civil(1969, 12, 31), -1);
    }

    #[test]
    fn dates() {
        assert_eq!(parse_date(b"2024-02-29"), Some((2024, 2, 29, 0, 0, 0, 0)));
        assert_eq!(
            parse_date(b"2024-02-29 13:14:15.5"),
            Some((2024, 2, 29, 13, 14, 15, 500_000))
        );
        assert_eq!(parse_date(b"nope"), None);
    }

    #[test]
    fn requests() {
        let mut b = Vec::new();
        b.extend_from_slice(&7u64.to_le_bytes());
        b.extend_from_slice(&1u64.to_le_bytes());
        b.extend_from_slice(&0u64.to_le_bytes());
        b.extend_from_slice(&[OP_QUERY, 0, 0, 0]);
        b.extend_from_slice(&8u32.to_le_bytes());
        b.extend_from_slice(&2u32.to_le_bytes());
        b.extend_from_slice(b"SELECT ?");
        b.push(T_INT);
        b.extend_from_slice(&5i64.to_le_bytes());
        b.push(T_TEXT);
        b.extend_from_slice(&2u32.to_le_bytes());
        b.extend_from_slice(b"hi");
        let mut r = Reader(&b);
        let req = read_request(&mut r).unwrap();
        assert_eq!((req.id, req.pool, req.op), (7, 1, OP_QUERY));
        assert_eq!(req.sql, "SELECT ?");
        assert_eq!(
            req.params,
            vec![Value::Int(5), Value::Bytes(b"hi".to_vec())]
        );
        assert!(read_request(&mut r).is_none());
        // a cut record is ignored
        let mut r = Reader(&b[..b.len() - 1]);
        assert!(read_request(&mut r).is_none());
    }
}

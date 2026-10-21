//! Native HTTP/1.1 server for Dart (dox_http_native).
//!
//! Rust only owns the sockets and parses HTTP (hyper 1.x). All app code
//! stays in Dart. Each server runs on its own thread with one tokio
//! `current_thread` runtime. One Dart isolate starts one server.
//!
//! Flow: parsed requests are added to a batch. Once per runtime tick the
//! batch is posted to a Dart `ReceivePort` with `Dart_PostCObject`. Dart
//! runs the handlers and sends all answers back in one leaf FFI call,
//! `dox_respond_batch`.
//!
//! Request record (little endian, 28 byte head): u64 id, u32 flags
//! (bit 0: HTTP/1.0), u16 method_len, u16 target_len, u32 headers_len,
//! u32 body_len, u16 remote_port, u16 reserved. Then 16 bytes remote ip
//! (IPv6, IPv4 is mapped), method, target, "name: value\r\n" lines, body.
//!
//! Response record (20 byte head): u64 id, u16 status, u16 flags,
//! u32 headers_len, u32 body_len. Then header lines, body.
use std::cell::{Cell, RefCell};
use std::convert::Infallible;
use std::ffi::{CStr, c_char, c_int, c_void};
use std::net::{IpAddr, SocketAddr, TcpListener as StdListener};
use std::pin::Pin;
use std::rc::Rc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::task::{Context, Poll};
use std::thread::JoinHandle;
use std::time::Duration;

use bytes::Bytes;
use http_body_util::{BodyExt, Full};
use hyper::body::{Body, Incoming};
use hyper::header::{CONTENT_LENGTH, EXPECT, HeaderName, HeaderValue};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response, StatusCode, Version};
use hyper_util::rt::{TokioIo, TokioTimer};
use slab::Slab;
use socket2::{Domain, Protocol, Socket, Type};
use tokio::io::{AsyncRead, AsyncWrite, ReadBuf};
use tokio::net::TcpStream;
use tokio::sync::{Notify, oneshot};

/// Bump when the FFI functions or the record layout change.
const ABI_VERSION: i32 = 1;
/// Max size of the request line plus headers. Bigger gets 431.
const MAX_HEAD: usize = 16 * 1024;
const RES_HEAD: usize = 20;
/// Bytes a too big body may still send before the connection is closed.
const DRAIN_MAX: usize = 64 * 1024 * 1024;

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

// ---- server ------------------------------------------------------------

type Answer = Response<Full<Bytes>>;

/// Shared by the Dart thread (answers) and the server thread.
struct Server {
    pending: Mutex<Slab<oneshot::Sender<Answer>>>,
    stopped: AtomicBool,
    stop: Notify,
    port: u16,
    thread: Mutex<Option<JoinHandle<()>>>,
}

impl Server {
    fn shut_down(&self) {
        self.stopped.store(true, Ordering::Release);
        self.stop.notify_one();
    }
}

/// State of one server thread. Only that thread touches it.
struct Ctx {
    server: Arc<Server>,
    batch: RefCell<Vec<u8>>,
    notify: Notify,
    max_body: usize,
}

fn bind_new(port: u16) -> std::io::Result<StdListener> {
    // dual stack like dart:io `anyIPv6`. IPv4 only when there is no IPv6.
    let (socket, addr) = match Socket::new(Domain::IPV6, Type::STREAM, Some(Protocol::TCP)) {
        Ok(s) if s.set_only_v6(false).is_ok() => (s, SocketAddr::from(([0u16; 8], port))),
        _ => (
            Socket::new(Domain::IPV4, Type::STREAM, Some(Protocol::TCP))?,
            SocketAddr::from(([0, 0, 0, 0], port)),
        ),
    };
    #[cfg(unix)]
    socket.set_reuse_address(true)?;
    // Linux spreads connections over SO_REUSEPORT sockets: one per isolate.
    #[cfg(any(target_os = "linux", target_os = "android"))]
    socket.set_reuse_port(true)?;
    socket.bind(&addr.into())?;
    socket.listen(1024)?;
    socket.set_nonblocking(true)?;
    Ok(socket.into())
}

/// Listening sockets of this process by port, with a user count.
/// macOS does not spread connections over SO_REUSEPORT sockets (one gets
/// all), so there every isolate gets a copy (dup) of one socket and they
/// all accept from the same queue. Windows runs one isolate (see DoxServer).
#[cfg(not(any(target_os = "linux", target_os = "android")))]
static LISTENERS: Mutex<Vec<(u16, StdListener, usize)>> = Mutex::new(Vec::new());

#[cfg(any(target_os = "linux", target_os = "android"))]
fn bind(port: u16) -> std::io::Result<StdListener> {
    bind_new(port)
}

#[cfg(any(target_os = "linux", target_os = "android"))]
fn unbind(_port: u16) {}

#[cfg(not(any(target_os = "linux", target_os = "android")))]
fn bind(port: u16) -> std::io::Result<StdListener> {
    let mut all = LISTENERS.lock().unwrap();
    if port != 0
        && let Some(entry) = all.iter_mut().find(|e| e.0 == port)
    {
        entry.2 += 1;
        return entry.1.try_clone();
    }
    let listener = bind_new(port)?;
    let real = listener.local_addr()?.port();
    all.push((real, listener.try_clone()?, 1));
    Ok(listener)
}

#[cfg(not(any(target_os = "linux", target_os = "android")))]
fn unbind(port: u16) {
    let mut all = LISTENERS.lock().unwrap();
    if let Some(i) = all.iter().position(|e| e.0 == port) {
        all[i].2 -= 1;
        if all[i].2 == 0 {
            all.swap_remove(i); // closes the last copy: the port is free
        }
    }
}

thread_local! {
    /// true while `serve` runs on this thread (tasks can be spawned).
    static SERVING: Cell<bool> = const { Cell::new(false) };
}

/// A TCP stream that closes gently ("lingering close"). When hyper drops
/// it, unread bytes from the client would make the OS send a reset, and the
/// client could lose our last answer (eg. 431 or 413). So first close our
/// side, then read and drop what is left for up to one second.
struct Lingering(Option<TcpStream>);

impl Lingering {
    fn io(self: Pin<&mut Self>) -> Pin<&mut TcpStream> {
        Pin::new(self.get_mut().0.as_mut().expect("stream"))
    }
}

impl AsyncRead for Lingering {
    fn poll_read(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &mut ReadBuf<'_>,
    ) -> Poll<std::io::Result<()>> {
        self.io().poll_read(cx, buf)
    }
}

impl AsyncWrite for Lingering {
    fn poll_write(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &[u8],
    ) -> Poll<std::io::Result<usize>> {
        self.io().poll_write(cx, buf)
    }

    fn poll_write_vectored(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        bufs: &[std::io::IoSlice<'_>],
    ) -> Poll<std::io::Result<usize>> {
        self.io().poll_write_vectored(cx, bufs)
    }

    fn is_write_vectored(&self) -> bool {
        true
    }

    fn poll_flush(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<std::io::Result<()>> {
        self.io().poll_flush(cx)
    }

    fn poll_shutdown(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<std::io::Result<()>> {
        self.io().poll_shutdown(cx)
    }
}

impl Drop for Lingering {
    fn drop(&mut self) {
        let Some(mut stream) = self.0.take() else {
            return;
        };
        if !SERVING.with(Cell::get) {
            return; // the server stops: close at once
        }
        tokio::task::spawn_local(async move {
            use tokio::io::{AsyncReadExt, AsyncWriteExt};
            let _ = stream.shutdown().await;
            let mut buf = [0u8; 4096];
            let drain = async {
                let mut total = 0;
                while let Ok(n) = stream.read(&mut buf).await {
                    total += n;
                    if n == 0 || total > 1 << 20 {
                        break;
                    }
                }
            };
            let _ = tokio::time::timeout(Duration::from_secs(1), drain).await;
        });
    }
}

/// The peer as 16 bytes ip (IPv4 mapped) and a port.
fn peer_bytes(addr: SocketAddr) -> [u8; 18] {
    let ip = match addr.ip() {
        IpAddr::V4(v4) => v4.to_ipv6_mapped(),
        IpAddr::V6(v6) => v6,
    };
    let mut out = [0u8; 18];
    out[..16].copy_from_slice(&ip.octets());
    out[16..].copy_from_slice(&addr.port().to_le_bytes());
    out
}

async fn serve(listener: StdListener, ctx: Rc<Ctx>, dart_port: i64) {
    let listener = tokio::net::TcpListener::from_std(listener).expect("listener");
    tokio::task::spawn_local(flusher(ctx.clone(), dart_port));
    let server = ctx.server.clone();
    SERVING.with(|s| s.set(true));
    while !server.stopped.load(Ordering::Acquire) {
        tokio::select! {
            biased;
            _ = server.stop.notified() => {}
            accepted = listener.accept() => {
                let (stream, addr) = match accepted {
                    Ok(v) => v,
                    Err(_) => {
                        // eg. too many open files. wait a bit, do not spin.
                        tokio::time::sleep(Duration::from_millis(10)).await;
                        continue;
                    }
                };
                let _ = stream.set_nodelay(true);
                let peer = peer_bytes(addr);
                let ctx = ctx.clone();
                tokio::task::spawn_local(async move {
                    let svc = service_fn(move |req| handle(req, ctx.clone(), peer));
                    // hyper answers 400 for a bad request and 431 when the
                    // head is bigger than MAX_HEAD, then closes the connection.
                    // Do not turn on pipeline_flush: then hyper drops that answer.
                    let _ = http1::Builder::new()
                        .timer(TokioTimer::new())
                        .keep_alive(true)
                        .half_close(true)
                        .max_buf_size(MAX_HEAD)
                        .serve_connection(TokioIo::new(Lingering(Some(stream))), svc)
                        .await;
                });
            }
        }
    }
    SERVING.with(|s| s.set(false));
}

async fn handle(
    req: Request<Incoming>,
    ctx: Rc<Ctx>,
    peer: [u8; 18],
) -> Result<Answer, Infallible> {
    let declared = req
        .headers()
        .get(CONTENT_LENGTH)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<u64>().ok());
    if declared.is_some_and(|n| n > ctx.max_body as u64) && req.headers().contains_key(EXPECT) {
        // the client waits for "100 Continue": say no before it sends the body
        return Ok(simple(StatusCode::PAYLOAD_TOO_LARGE));
    }
    let (parts, body) = req.into_parts();
    let body = if body.is_end_stream() {
        Vec::new()
    } else {
        let hint = declared.unwrap_or(0).min(ctx.max_body as u64) as usize;
        match read_body(body, ctx.max_body, hint).await {
            Ok(b) => b,
            Err(code) => return Ok(simple(code)),
        }
    };
    let target = parts
        .uri
        .path_and_query()
        .map(|p| p.as_str())
        .unwrap_or("/");
    let flags = u32::from(parts.version == Version::HTTP_10);
    let rx = enqueue(
        &ctx,
        flags,
        parts.method.as_str(),
        target,
        &parts.headers,
        &peer,
        &body,
    );
    Ok(rx
        .await
        .unwrap_or_else(|_| simple(StatusCode::SERVICE_UNAVAILABLE)))
}

/// Reads the whole body. Over `max` bytes it keeps reading (and drops the
/// bytes) up to DRAIN_MAX more, so the client can finish sending and read
/// the 413. Closing at once gives the client a broken pipe instead.
async fn read_body(mut body: Incoming, max: usize, hint: usize) -> Result<Vec<u8>, StatusCode> {
    let mut buf = Vec::with_capacity(hint);
    let mut seen = 0usize;
    while let Some(frame) = body.frame().await {
        let Ok(frame) = frame else {
            return Err(StatusCode::BAD_REQUEST);
        };
        let Ok(data) = frame.into_data() else {
            continue;
        };
        seen += data.len();
        if seen > max {
            if seen > max.saturating_add(DRAIN_MAX) {
                break;
            }
            continue;
        }
        buf.extend_from_slice(&data);
    }
    if seen > max {
        Err(StatusCode::PAYLOAD_TOO_LARGE)
    } else {
        Ok(buf)
    }
}

/// Adds one request record to the batch. Returns where the answer will arrive.
fn enqueue(
    ctx: &Ctx,
    flags: u32,
    method: &str,
    target: &str,
    headers: &hyper::HeaderMap,
    peer: &[u8; 18],
    body: &[u8],
) -> oneshot::Receiver<Answer> {
    let (tx, rx) = oneshot::channel();
    let id = ctx.server.pending.lock().unwrap().insert(tx) as u64;
    let mut b = ctx.batch.borrow_mut();
    let was_empty = b.is_empty();
    let (method, target) = (method.as_bytes(), target.as_bytes());
    b.extend_from_slice(&id.to_le_bytes());
    b.extend_from_slice(&flags.to_le_bytes());
    b.extend_from_slice(&(method.len() as u16).to_le_bytes());
    b.extend_from_slice(&(target.len() as u16).to_le_bytes());
    let hlen_at = b.len();
    b.extend_from_slice(&0u32.to_le_bytes());
    b.extend_from_slice(&(body.len() as u32).to_le_bytes());
    b.extend_from_slice(&peer[16..]);
    b.extend_from_slice(&[0, 0]);
    b.extend_from_slice(&peer[..16]);
    b.extend_from_slice(method);
    b.extend_from_slice(target);
    let hstart = b.len();
    for (k, v) in headers {
        b.extend_from_slice(k.as_str().as_bytes());
        b.extend_from_slice(b": ");
        b.extend_from_slice(v.as_bytes());
        b.extend_from_slice(b"\r\n");
    }
    let hlen = (b.len() - hstart) as u32;
    b[hlen_at..hlen_at + 4].copy_from_slice(&hlen.to_le_bytes());
    b.extend_from_slice(body);
    if was_empty {
        ctx.notify.notify_one();
    }
    rx
}

fn simple(code: StatusCode) -> Answer {
    let mut r = Response::new(Full::new(Bytes::new()));
    *r.status_mut() = code;
    r
}

/// Posts the batch once all tasks that are ready this tick have added to it.
async fn flusher(ctx: Rc<Ctx>, port: i64) {
    let mut out = Vec::new();
    loop {
        ctx.notify.notified().await;
        tokio::task::yield_now().await;
        std::mem::swap(&mut out, &mut *ctx.batch.borrow_mut());
        if out.is_empty() {
            continue;
        }
        if !post(port, &out) {
            // the isolate is gone (killed or closed). stop this server so
            // the port is free for a new isolate.
            ctx.server.shut_down();
            return;
        }
        out.clear();
        if out.capacity() > 1 << 20 {
            out = Vec::new(); // do not keep a big body buffer forever
        }
    }
}

// ---- FFI ---------------------------------------------------------------

/// ABI version of this library. Dart checks it at load.
#[unsafe(no_mangle)]
pub extern "C" fn dox_version() -> i32 {
    ABI_VERSION
}

/// Reads `Dart_PostCObject` from `NativeApi.initializeApiDLData`.
/// Returns 0 on success.
///
/// # Safety
/// `data` must be `NativeApi.initializeApiDLData`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dox_init(data: *mut c_void) -> i32 {
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

/// Binds `port` and starts a server thread that posts to `send_port`.
/// Returns a handle (> 0), or < 0: -1 not initialized, -(1000 + errno)
/// when the bind fails.
#[unsafe(no_mangle)]
pub extern "C" fn dox_start(port: i32, send_port: i64, max_body: i64) -> i64 {
    if POST.get().is_none() {
        return -1;
    }
    let listener = match bind(port as u16) {
        Ok(l) => l,
        Err(e) => return -(1000 + i64::from(e.raw_os_error().unwrap_or(0))),
    };
    let port = listener.local_addr().map(|a| a.port()).unwrap_or(0);
    let server = Arc::new(Server {
        pending: Mutex::new(Slab::with_capacity(1024)),
        stopped: AtomicBool::new(false),
        stop: Notify::new(),
        port,
        thread: Mutex::new(None),
    });
    let for_thread = server.clone();
    let max_body = max_body.max(0) as usize;
    let thread = std::thread::Builder::new()
        .name("dox-http".into())
        .spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("runtime");
            let local = tokio::task::LocalSet::new();
            let ctx = Rc::new(Ctx {
                server: for_thread,
                batch: RefCell::new(Vec::with_capacity(1 << 16)),
                notify: Notify::new(),
                max_body,
            });
            local.block_on(&rt, serve(listener, ctx, send_port));
            drop(local); // closes every open connection
            unbind(port);
        });
    match thread {
        Ok(t) => *server.thread.lock().unwrap() = Some(t),
        Err(_) => return -2,
    }
    Arc::into_raw(server) as i64
}

/// The port the server listens on (useful for port 0).
///
/// # Safety
/// `handle` must come from `dox_start` and not be stopped.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dox_port(handle: i64) -> i32 {
    let server = unsafe { &*(handle as *const Server) };
    i32::from(server.port)
}

/// Stops the server, closes its connections and frees the handle.
///
/// # Safety
/// `handle` must come from `dox_start`. Do not use it after this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dox_stop(handle: i64) {
    let server = unsafe { Arc::from_raw(handle as *const Server) };
    server.shut_down();
    let thread = server.thread.lock().unwrap().take();
    if let Some(t) = thread {
        let _ = t.join();
    }
}

fn rd16(b: &[u8], p: usize) -> u16 {
    u16::from_le_bytes([b[p], b[p + 1]])
}

fn rd32(b: &[u8], p: usize) -> usize {
    u32::from_le_bytes(b[p..p + 4].try_into().unwrap()) as usize
}

/// Called from Dart (leaf call) with a batch of response records.
///
/// # Safety
/// `handle` must come from `dox_start` and not be stopped. `ptr` must
/// point to `len` readable bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dox_respond_batch(handle: i64, ptr: *const u8, len: i64) {
    let server = unsafe { &*(handle as *const Server) };
    let b = unsafe { std::slice::from_raw_parts(ptr, len as usize) };
    let mut answers = Vec::new();
    let mut p = 0;
    while p + RES_HEAD <= b.len() {
        let id = u64::from_le_bytes(b[p..p + 8].try_into().unwrap()) as usize;
        let status = rd16(b, p + 8);
        let hlen = rd32(b, p + 12);
        let blen = rd32(b, p + 16);
        let h_at = p + RES_HEAD;
        if h_at + hlen + blen > b.len() {
            break; // broken record: drop the rest
        }
        let headers = &b[h_at..h_at + hlen];
        let body = Bytes::copy_from_slice(&b[h_at + hlen..h_at + hlen + blen]);
        p = h_at + hlen + blen;
        let mut r = Response::new(Full::new(body));
        *r.status_mut() = StatusCode::from_u16(status).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR);
        for line in headers.split(|&c| c == b'\n') {
            let line = line.strip_suffix(b"\r").unwrap_or(line);
            let Some(colon) = line.iter().position(|&c| c == b':') else {
                continue;
            };
            let (Ok(k), Ok(v)) = (
                HeaderName::from_bytes(&line[..colon]),
                HeaderValue::from_bytes(line[colon + 1..].trim_ascii_start()),
            ) else {
                continue;
            };
            r.headers_mut().append(k, v);
        }
        answers.push((id, r));
    }
    let senders: Vec<_> = {
        let mut pending = server.pending.lock().unwrap();
        answers
            .into_iter()
            .filter_map(|(id, r)| pending.try_remove(id).map(|tx| (tx, r)))
            .collect()
    };
    for (tx, r) in senders {
        let _ = tx.send(r);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// a server with no Dart side. Only for answers that Rust gives itself.
    fn start_bare() -> u16 {
        let listener = bind(0).unwrap();
        let port = listener.local_addr().unwrap().port();
        let server = Arc::new(Server {
            pending: Mutex::new(Slab::new()),
            stopped: AtomicBool::new(false),
            stop: Notify::new(),
            port,
            thread: Mutex::new(None),
        });
        std::thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .unwrap();
            let local = tokio::task::LocalSet::new();
            let ctx = Rc::new(Ctx {
                server,
                batch: RefCell::new(Vec::new()),
                notify: Notify::new(),
                max_body: 10,
            });
            local.block_on(&rt, serve(listener, ctx, 0));
        });
        port
    }

    fn send(port: u16, req: &[u8]) -> String {
        use std::io::{Read, Write};
        let mut s = std::net::TcpStream::connect(("127.0.0.1", port)).unwrap();
        s.set_read_timeout(Some(Duration::from_secs(3))).unwrap();
        s.write_all(req).unwrap();
        let mut out = Vec::new();
        let _ = s.read_to_end(&mut out);
        String::from_utf8_lossy(&out).into_owned()
    }

    #[test]
    fn bad_requests_get_400_and_431() {
        let port = start_bare();
        assert!(
            send(port, b"HELLO\r\n\r\n").starts_with("HTTP/1.1 400"),
            "400"
        );
        let big = format!(
            "GET / HTTP/1.1\r\nHost: a\r\nX: {}\r\n\r\n",
            "a".repeat(20000)
        );
        assert!(
            send(port, big.as_bytes()).starts_with("HTTP/1.1 431"),
            "431"
        );
        let body = b"POST / HTTP/1.1\r\nHost: a\r\nContent-Length: 11\r\nConnection: close\r\n\r\nhello world";
        assert!(send(port, body).starts_with("HTTP/1.1 413"), "413");
    }

    #[test]
    fn peer_is_mapped_ipv6() {
        let p = peer_bytes("1.2.3.4:513".parse().unwrap());
        assert_eq!(&p[10..16], &[0xff, 0xff, 1, 2, 3, 4]);
        assert_eq!(u16::from_le_bytes([p[16], p[17]]), 513);
    }
}

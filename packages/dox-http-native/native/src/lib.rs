//! Native HTTP/1.1 server for Dart (dox_http_native).
//!
//! Rust only owns the sockets and parses HTTP (hyper 1.x). All app code
//! stays in Dart. One Dart isolate starts one server. All servers of the
//! process gets its own `dox-http` thread with one tokio `current_thread`
//! runtime. `DOX_HTTP_THREAD=shared` puts all servers on one thread. A
//! connection belongs to the server (isolate) whose socket accepted it, so
//! its requests stay in order on one isolate.
//!
//! Flow: parsed requests are added to a batch. Once per runtime tick the
//! batch is posted to a Dart `ReceivePort` with `Dart_PostCObject`. Dart
//! runs the handlers and sends all answers back in one leaf FFI call,
//! `dox_respond_batch`. It puts them in the server's inbox and wakes the
//! server thread once, not once per answer.
//!
//! Request record (little endian, 28 byte head): u64 id, u32 flags
//! (bit 0: HTTP/1.0), u16 method_len, u16 target_len, u32 headers_len,
//! u32 body_len, u16 remote_port, u16 reserved. Then 16 bytes remote ip
//! (IPv6, IPv4 is mapped), method, target, headers, body. Each header is
//! u16 name_len, u16 value_len, name (lowercase), value. With the lengths
//! Dart finds one header without reading every byte.
//!
//! Response record (20 byte head): u64 id, u16 status, u16 kind,
//! u32 headers_len, u32 body_len. Then header lines, body. Kind 0 is an
//! HTTP answer. The other kinds are for WebSockets, see below.
//!
//! WebSocket: a request that can upgrade (GET, HTTP/1.1, `Connection:
//! upgrade`, `Upgrade: websocket`, version 13, a key) gets flag bit 1. Dart
//! runs routing, middleware and the Origin check like for any request.
//! - Dart says no with a normal answer (eg. 403). There is no upgrade.
//! - Dart says yes with kind 1. The body is u64 ws id (Dart picks it) and
//!   u64 max message size. Its header lines (eg. `sec-websocket-protocol`)
//!   go on the `101` answer. Rust adds the upgrade headers.
//!
//! Then Rust speaks the WebSocket protocol (tokio-tungstenite): ping and
//! pong, the close handshake, the UTF-8 check of text and the size limit (a
//! bigger message or frame closes with 1009). It never agrees to
//! compression (permessage-deflate). Messages to Dart are request records
//! with a kind in flags bits 8 to 15: 1 text, 2 binary, 3 closed. Their id
//! is the ws id and their body the payload. For 3 the remote_port field is
//! the close code (1005: no code, 1006: no close frame) and the body the
//! reason. Rust sends exactly one kind 3 record per ws, when it ended.
//! Messages from Dart are response records: kind 2 text, 3 binary, 4 close
//! (status: the close code, 0 for none. body: the reason).
use std::cell::RefCell;
use std::collections::HashMap;
use std::convert::Infallible;
use std::ffi::{CStr, c_char, c_int, c_void};
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr, TcpListener as StdListener};
use std::pin::Pin;
use std::rc::Rc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, OnceLock, mpsc};
use std::task::{Context, Poll};
use std::thread::JoinHandle;
use std::time::Duration;

use bytes::Bytes;
use futures_util::{SinkExt, StreamExt};
use http_body_util::{BodyExt, Full};
use hyper::body::{Body, Incoming};
use hyper::header::{
    CONNECTION, CONTENT_LENGTH, CONTENT_TYPE, EXPECT, HeaderName, HeaderValue,
    SEC_WEBSOCKET_ACCEPT, SEC_WEBSOCKET_KEY, SEC_WEBSOCKET_VERSION, UPGRADE,
};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Method, Request, Response, StatusCode, Version};
use hyper_util::rt::{TokioIo, TokioTimer};
use slab::Slab;
use socket2::{Domain, Protocol, Socket, Type};
use tokio::io::{AsyncRead, AsyncWrite, ReadBuf};
use tokio::net::TcpStream;
use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender, unbounded_channel};
use tokio::sync::{Notify, oneshot};
use tokio::task::JoinSet;
use tokio_tungstenite::WebSocketStream;
use tokio_tungstenite::tungstenite::handshake::derive_accept_key;
use tokio_tungstenite::tungstenite::protocol::frame::coding::CloseCode;
use tokio_tungstenite::tungstenite::protocol::{CloseFrame, Role, WebSocketConfig};
use tokio_tungstenite::tungstenite::{Error as WsError, Message, Utf8Bytes};

/// Bump when the FFI functions or the record layout change.
const ABI_VERSION: i32 = 5;
/// Max size of the request line plus headers. Bigger gets 431.
const MAX_HEAD: usize = 16 * 1024;
const RES_HEAD: usize = 20;
/// Bytes a too big body may still send before the connection is closed.
const DRAIN_MAX: usize = 64 * 1024 * 1024;
/// Most memory we reserve up front for a body. `Content-Length` comes from
/// the client, so a bigger body grows the buffer only as bytes arrive.
const MAX_RESERVE: u64 = 64 * 1024;
/// WebSocket message kinds to Dart (flags bits 8 to 15 of a request record)
const WS_TEXT: u32 = 1;
const WS_BINARY: u32 = 2;
const WS_CLOSED: u32 = 3;
/// How long a closing WebSocket waits for the close frame of the peer.
/// Same as dart:io.
const CLOSE_WAIT: Duration = Duration::from_secs(5);

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

/// What Dart sends back.
enum Out {
    /// request id, its answer, and (ws id, max message size) when it
    /// accepts a WebSocket upgrade
    Http(usize, Answer, Option<(u64, usize)>),
    /// a message for the WebSocket with this id
    Ws(u64, Message),
}

/// A WebSocket upgrade that Dart accepted.
struct Accepted {
    id: u64,
    max: usize,
    /// the messages from Dart
    rx: UnboundedReceiver<Message>,
}

/// What a request gets from Dart: the answer, and the WebSocket when the
/// answer accepts an upgrade.
type Reply = (Answer, Option<Accepted>);

/// Shared by the Dart thread (answers) and the server thread.
struct Server {
    /// answers from Dart, by request id. The server thread hands them out.
    /// One lock and one wake per batch, not one per answer.
    inbox: Mutex<Vec<Out>>,
    answered: Notify,
    stopped: AtomicBool,
    /// `dox_shutdown` was called: stop accepting, let open requests finish
    draining: AtomicBool,
    stop: Notify,
    port: u16,
    /// the address it listens on, for `unbind`
    key: Key,
    /// own thread mode: the server thread
    thread: Mutex<Option<JoinHandle<()>>>,
    /// shared thread mode: gets a message (or closes) when the server ended
    done: Mutex<Option<mpsc::Receiver<()>>>,
}

impl Server {
    fn new(key: Key) -> Self {
        Server {
            inbox: Mutex::new(Vec::new()),
            answered: Notify::new(),
            stopped: AtomicBool::new(false),
            draining: AtomicBool::new(false),
            stop: Notify::new(),
            port: key.3,
            key,
            thread: Mutex::new(None),
            done: Mutex::new(None),
        }
    }

    fn shut_down(&self) {
        self.stopped.store(true, Ordering::Release);
        self.stop.notify_one();
    }

    fn drain(&self) {
        self.draining.store(true, Ordering::Release);
        self.stop.notify_one();
    }

    /// waits until `dox_stop` (or a dead isolate) stops the server
    async fn wait_stopped(&self) {
        while !self.stopped.load(Ordering::Acquire) {
            self.stop.notified().await;
        }
    }
}

/// State of one server thread. Only that thread touches it.
struct Ctx {
    server: Arc<Server>,
    /// requests that wait for an answer from Dart
    pending: RefCell<Slab<oneshot::Sender<Reply>>>,
    batch: RefCell<Vec<u8>>,
    notify: Notify,
    limits: Limits,
    /// tells every open connection to close after its current request
    closing: Notify,
    /// open WebSockets by ws id: where messages from Dart go
    sockets: RefCell<HashMap<u64, UnboundedSender<Message>>>,
    /// the WebSocket tasks. Aborted when the server stops.
    ws_tasks: RefCell<JoinSet<()>>,
}

impl Ctx {
    fn new(server: Arc<Server>, limits: Limits) -> Self {
        Ctx {
            server,
            pending: RefCell::new(Slab::with_capacity(1024)),
            batch: RefCell::new(Vec::with_capacity(1 << 16)),
            notify: Notify::new(),
            limits,
            closing: Notify::new(),
            sockets: RefCell::new(HashMap::new()),
            ws_tasks: RefCell::new(JoinSet::new()),
        }
    }
}

/// Body limits of one server.
#[derive(Clone, Copy)]
struct Limits {
    /// max bytes of a body that is not a multipart form
    body: usize,
    /// max bytes of a multipart form (file uploads)
    multipart: usize,
    /// max idle time with no body bytes. Longer gets 408.
    timeout: Duration,
}

impl Limits {
    /// The max body size for a request with these headers. Only a
    /// multipart form gets the bigger limit, the same check as Dart.
    fn max_for(&self, headers: &hyper::HeaderMap) -> usize {
        let form = headers
            .get(CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.split(';').next())
            .is_some_and(|m| m.to_ascii_lowercase().contains("form-data"));
        if form { self.multipart } else { self.body }
    }
}

/// The address to listen on: (family, high 64 bits, low 64 bits, port).
/// family 0: all interfaces, IPv6 and IPv4 (dual stack, like dart:io
/// `anyIPv6`). 4: the IPv4 address in the low 32 bits. 6: an IPv6 address.
type Key = (i32, u64, u64, u16);

fn socket_addr(key: Key) -> Option<SocketAddr> {
    let (family, hi, lo, port) = key;
    match family {
        4 => Some(SocketAddr::from((Ipv4Addr::from(lo as u32), port))),
        6 => Some(SocketAddr::from((
            Ipv6Addr::from((u128::from(hi) << 64) | u128::from(lo)),
            port,
        ))),
        _ => None,
    }
}

fn bind_new(key: Key) -> std::io::Result<StdListener> {
    let port = key.3;
    let (socket, addr) = match socket_addr(key) {
        Some(addr) => {
            let s = Socket::new(Domain::for_address(addr), Type::STREAM, Some(Protocol::TCP))?;
            if addr.is_ipv6() {
                let _ = s.set_only_v6(false); // `::` also takes IPv4, like dart:io
            }
            (s, addr)
        }
        // dual stack like dart:io `anyIPv6`. IPv4 only when there is no IPv6.
        None => match Socket::new(Domain::IPV6, Type::STREAM, Some(Protocol::TCP)) {
            Ok(s) if s.set_only_v6(false).is_ok() => (s, SocketAddr::from(([0u16; 8], port))),
            _ => (
                Socket::new(Domain::IPV4, Type::STREAM, Some(Protocol::TCP))?,
                SocketAddr::from(([0, 0, 0, 0], port)),
            ),
        },
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

/// Listening sockets of this process by address, with a user count.
/// macOS does not spread connections over SO_REUSEPORT sockets (one gets
/// all), so there every isolate gets a copy (dup) of one socket and they
/// all accept from the same queue. Windows runs one isolate (see DoxServer).
#[cfg(not(any(target_os = "linux", target_os = "android")))]
static LISTENERS: Mutex<Vec<(Key, StdListener, usize)>> = Mutex::new(Vec::new());

/// Binds `key`. Returns the listener and the key with the real port.
#[cfg(any(target_os = "linux", target_os = "android"))]
fn bind(key: Key) -> std::io::Result<(StdListener, Key)> {
    let listener = bind_new(key)?;
    let port = listener.local_addr()?.port();
    Ok((listener, (key.0, key.1, key.2, port)))
}

#[cfg(any(target_os = "linux", target_os = "android"))]
fn unbind(_key: Key) {}

#[cfg(not(any(target_os = "linux", target_os = "android")))]
fn bind(key: Key) -> std::io::Result<(StdListener, Key)> {
    let mut all = LISTENERS.lock().unwrap();
    if key.3 != 0
        && let Some(entry) = all.iter_mut().find(|e| e.0 == key)
    {
        entry.2 += 1;
        return Ok((entry.1.try_clone()?, key));
    }
    let listener = bind_new(key)?;
    let real = (key.0, key.1, key.2, listener.local_addr()?.port());
    all.push((real, listener.try_clone()?, 1));
    Ok((listener, real))
}

#[cfg(not(any(target_os = "linux", target_os = "android")))]
fn unbind(key: Key) {
    let mut all = LISTENERS.lock().unwrap();
    if let Some(i) = all.iter().position(|e| e.0 == key) {
        all[i].2 -= 1;
        if all[i].2 == 0 {
            all.swap_remove(i); // closes the last copy: the port is free
        }
    }
}

/// A TCP stream that closes gently ("lingering close"). When hyper drops
/// it, unread bytes from the client would make the OS send a reset, and the
/// client could lose our last answer (eg. 431 or 413). So first close our
/// side, then read and drop what is left for up to one second.
struct Lingering(Option<TcpStream>, Arc<Server>);

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
        if self.1.stopped.load(Ordering::Acquire) {
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
    let key = ctx.server.key;
    let listener = tokio::net::TcpListener::from_std(listener).expect("listener");
    // every task of this server. Dropping it at the end closes them all,
    // also when other servers still run on the same thread.
    let mut tasks = JoinSet::new();
    tasks.spawn_local(flusher(ctx.clone(), dart_port));
    tasks.spawn_local(deliver(ctx.clone()));
    // the connections, apart, so a shutdown can wait for them
    let mut conns = JoinSet::new();
    let server = ctx.server.clone();
    while !server.stopped.load(Ordering::Acquire) && !server.draining.load(Ordering::Acquire) {
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
                while conns.try_join_next().is_some() {} // forget closed ones
                conns.spawn_local(connection(stream, peer, ctx));
                // let the accept loops of other servers on this thread take
                // a turn. On macOS they all accept from one queue.
                tokio::task::yield_now().await;
            }
        }
    }
    // no new connections from here on. The port is free when the last
    // server of this address stops.
    drop(listener);
    unbind(key);
    if !server.stopped.load(Ordering::Acquire) {
        // graceful shutdown: each connection closes after its current
        // answer, each WebSocket with 1001 (going away). Dart still answers
        // the open requests. `dox_stop` ends the wait early.
        ctx.closing.notify_waiters();
        let mut sockets = std::mem::take(&mut *ctx.ws_tasks.borrow_mut());
        tokio::select! {
            _ = async {
                while conns.join_next().await.is_some() {}
                while sockets.join_next().await.is_some() {}
            } => {}
            _ = server.wait_stopped() => {}
        }
        // the close records of the WebSockets first, then the done byte
        let last = std::mem::take(&mut *ctx.batch.borrow_mut());
        if !last.is_empty() {
            post(dart_port, &last);
        }
        post(dart_port, &[1]); // tell Dart: all open requests are done
        server.wait_stopped().await;
    }
    // the WebSocket tasks hold the ctx. Stop them so it is freed.
    ctx.ws_tasks.borrow_mut().abort_all();
}

/// Serves one connection until the client closes it, or until a
/// shutdown, after the request it is busy with.
async fn connection(stream: TcpStream, peer: [u8; 18], ctx: Rc<Ctx>) {
    // made before the check, so a shutdown between the two is not missed
    let watch = ctx.clone();
    let closing = watch.closing.notified();
    let shut_down = ctx.server.draining.load(Ordering::Acquire);
    let ctx2 = ctx.clone();
    let svc = service_fn(move |req| handle(req, ctx2.clone(), peer));
    // hyper answers 400 for a bad request and 431 when the
    // head is bigger than MAX_HEAD, then closes the connection.
    // Do not turn on pipeline_flush: then hyper drops that answer.
    let conn = http1::Builder::new()
        .timer(TokioTimer::new())
        .keep_alive(true)
        .half_close(true)
        .max_buf_size(MAX_HEAD)
        .serve_connection(
            TokioIo::new(Lingering(Some(stream), ctx.server.clone())),
            svc,
        )
        .with_upgrades();
    let mut conn = std::pin::pin!(conn);
    if !shut_down {
        tokio::select! {
            _ = conn.as_mut() => return,
            _ = closing => {}
        }
    }
    conn.as_mut().graceful_shutdown();
    let _ = conn.await;
}

/// Runs one server until it stops, then frees its port.
async fn run_server(listener: StdListener, server: Arc<Server>, dart_port: i64, limits: Limits) {
    serve(listener, Rc::new(Ctx::new(server, limits)), dart_port).await;
}

fn new_runtime() -> tokio::runtime::Runtime {
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("runtime")
}

/// true: one `dox-http` thread serves the servers of all isolates.
/// Off by default: `DOX_HTTP_THREAD=shared` turns it on. On 2 cores the one
/// thread was the limit (about 115% CPU) and req/s fell by a quarter.
fn shared_thread() -> bool {
    static SHARED: OnceLock<bool> = OnceLock::new();
    *SHARED.get_or_init(|| std::env::var("DOX_HTTP_THREAD").is_ok_and(|v| v == "shared"))
}

type Job = Box<dyn FnOnce() + Send>;

/// The shared `dox-http` thread. It runs while at least one server uses it.
struct SharedThread {
    jobs: tokio::sync::mpsc::UnboundedSender<Job>,
    users: usize,
    _thread: JoinHandle<()>,
}

static SHARED_THREAD: Mutex<Option<SharedThread>> = Mutex::new(None);

/// Starts `server` on the shared thread. Starts the thread when needed.
fn start_shared(
    listener: StdListener,
    server: Arc<Server>,
    dart_port: i64,
    limits: Limits,
) -> bool {
    let (done_tx, done_rx) = mpsc::channel();
    *server.done.lock().unwrap() = Some(done_rx);
    let job: Job = Box::new(move || {
        tokio::task::spawn_local(async move {
            run_server(listener, server, dart_port, limits).await;
            // also runs for a killed isolate, which never calls dox_stop
            leave_shared();
            let _ = done_tx.send(());
        });
    });
    let mut shared = SHARED_THREAD.lock().unwrap();
    if shared.is_none() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel::<Job>();
        let thread = std::thread::Builder::new()
            .name("dox-http".into())
            .spawn(move || {
                let rt = new_runtime();
                let local = tokio::task::LocalSet::new();
                local.block_on(&rt, async move {
                    // ends when the last server stopped (the sender is dropped)
                    while let Some(job) = rx.recv().await {
                        job();
                    }
                });
            });
        let Ok(thread) = thread else { return false };
        *shared = Some(SharedThread {
            jobs: tx,
            users: 0,
            _thread: thread,
        });
    }
    let t = shared.as_mut().unwrap();
    t.users += 1;
    t.jobs.send(job).is_ok()
}

/// One server of the shared thread ended. After the last one the thread
/// ends by itself (its job channel closes). A new server starts a new one.
/// Runs on the shared thread, so it can not join it.
fn leave_shared() {
    let mut shared = SHARED_THREAD.lock().unwrap();
    if let Some(t) = shared.as_mut() {
        t.users -= 1;
        if t.users == 0 {
            *shared = None; // drops the sender and the join handle
        }
    }
}

async fn handle(
    mut req: Request<Incoming>,
    ctx: Rc<Ctx>,
    peer: [u8; 18],
) -> Result<Answer, Infallible> {
    let ws_key = ws_key(&req);
    let on_upgrade = ws_key.is_some().then(|| hyper::upgrade::on(&mut req));
    let (parts, body) = req.into_parts();
    let max = ctx.limits.max_for(&parts.headers);
    let declared = parts
        .headers
        .get(CONTENT_LENGTH)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<u64>().ok());
    let waits = parts
        .headers
        .get(EXPECT)
        .is_some_and(|v| v.as_bytes().eq_ignore_ascii_case(b"100-continue"));
    if waits && declared.is_some_and(|n| n > max as u64) {
        // too big, and the client waits for our go before it sends the
        // body: say no at once. Any other client is already sending, so
        // read_body drops its bytes first. Else it sees a reset, not 413.
        return Ok(simple(StatusCode::PAYLOAD_TOO_LARGE));
    }
    let body = if body.is_end_stream() {
        Vec::new()
    } else {
        let hint = declared.unwrap_or(0).min(MAX_RESERVE) as usize;
        match read_body(body, max, hint, ctx.limits.timeout).await {
            Ok(b) => b,
            Err(code) => return Ok(simple(code)),
        }
    };
    let target = parts
        .uri
        .path_and_query()
        .map(|p| p.as_str())
        .unwrap_or("/");
    let flags = u32::from(parts.version == Version::HTTP_10) | (u32::from(ws_key.is_some()) << 1);
    let rx = enqueue(
        &ctx,
        flags,
        parts.method.as_str(),
        target,
        &parts.headers,
        &peer,
        &body,
    );
    let Ok((mut answer, accepted)) = rx.await else {
        return Ok(simple(StatusCode::SERVICE_UNAVAILABLE));
    };
    let Some(accepted) = accepted else {
        return Ok(answer);
    };
    let (Some(key), Some(on_upgrade)) = (ws_key, on_upgrade) else {
        // Dart accepted a request that can not upgrade
        ctx.sockets.borrow_mut().remove(&accepted.id);
        enqueue_ws(&ctx, accepted.id, WS_CLOSED, 1006, b"");
        return Ok(simple(StatusCode::BAD_REQUEST));
    };
    *answer.status_mut() = StatusCode::SWITCHING_PROTOCOLS;
    let h = answer.headers_mut();
    h.insert(UPGRADE, HeaderValue::from_static("websocket"));
    h.insert(CONNECTION, HeaderValue::from_static("Upgrade"));
    if let Ok(v) = HeaderValue::from_str(&derive_accept_key(key.as_bytes())) {
        h.insert(SEC_WEBSOCKET_ACCEPT, v);
    }
    let mut tasks = ctx.ws_tasks.borrow_mut();
    while tasks.try_join_next().is_some() {} // forget closed ones
    tasks.spawn_local(websocket(on_upgrade, accepted, ctx.clone()));
    Ok(answer)
}

/// The `Sec-WebSocket-Key` of a request that can upgrade to a WebSocket.
fn ws_key<B>(req: &Request<B>) -> Option<HeaderValue> {
    let h = req.headers();
    let has = |name: HeaderName, token: &str| {
        h.get_all(name).iter().any(|v| {
            v.to_str()
                .is_ok_and(|v| v.split(',').any(|t| t.trim().eq_ignore_ascii_case(token)))
        })
    };
    let ok = req.method() == Method::GET
        && req.version() == Version::HTTP_11
        && has(CONNECTION, "upgrade")
        && has(UPGRADE, "websocket")
        && h.get(SEC_WEBSOCKET_VERSION).is_some_and(|v| v == "13");
    if ok {
        h.get(SEC_WEBSOCKET_KEY).cloned()
    } else {
        None
    }
}

/// Runs one accepted WebSocket, then tells Dart it closed.
async fn websocket(on_upgrade: hyper::upgrade::OnUpgrade, accepted: Accepted, ctx: Rc<Ctx>) {
    let Accepted { id, max, rx } = accepted;
    let (code, reason) = match on_upgrade.await {
        Ok(io) => run_ws(TokioIo::new(io), id, max, rx, &ctx).await,
        Err(_) => (1006, Bytes::new()),
    };
    ctx.sockets.borrow_mut().remove(&id);
    enqueue_ws(&ctx, id, WS_CLOSED, code, &reason);
}

/// Speaks the WebSocket protocol on `io` until the socket closes. Messages
/// from the client go to the batch. Messages from Dart come from `rx`.
/// Returns the close code and reason for Dart.
async fn run_ws<S>(
    io: S,
    id: u64,
    max: usize,
    mut rx: UnboundedReceiver<Message>,
    ctx: &Ctx,
) -> (u16, Bytes)
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let config = WebSocketConfig::default()
        .max_message_size(Some(max))
        .max_frame_size(Some(max));
    let mut ws = WebSocketStream::from_raw_socket(io, Role::Server, Some(config)).await;
    let closing = ctx.closing.notified();
    let mut closing = std::pin::pin!(closing);
    closing.as_mut().enable();
    if ctx.server.draining.load(Ordering::Acquire) {
        return close_ws(ws, CloseCode::Away).await;
    }
    // the close frame of the client, once it came
    let mut peer = None;
    loop {
        tokio::select! {
            msg = ws.next() => match msg {
                Some(Ok(Message::Text(t))) => enqueue_ws(ctx, id, WS_TEXT, 0, t.as_bytes()),
                Some(Ok(Message::Binary(b))) => enqueue_ws(ctx, id, WS_BINARY, 0, &b),
                // tungstenite answers it. The stream ends after that.
                Some(Ok(Message::Close(f))) => peer = Some(close_parts(f)),
                // tungstenite answers a ping itself
                Some(Ok(_)) => {}
                Some(Err(WsError::Capacity(_))) => return fail_ws(ws, CloseCode::Size).await,
                Some(Err(WsError::Utf8(_))) => return fail_ws(ws, CloseCode::Invalid).await,
                Some(Err(WsError::Protocol(_))) => return fail_ws(ws, CloseCode::Protocol).await,
                Some(Err(_)) => return (1006, Bytes::new()),
                None => return peer.unwrap_or((1006, Bytes::new())),
            },
            out = rx.recv() => match out {
                Some(Message::Close(frame)) => return close_ws_with(ws, frame).await,
                // a failed send also fails the next read, which ends the loop
                Some(m) => { let _ = ws.send(m).await; }
                None => return (1006, Bytes::new()),
            },
            _ = &mut closing => return close_ws(ws, CloseCode::Away).await,
        }
    }
}

/// (code, reason) of a close frame. No frame is 1005 (no status), like dart:io.
fn close_parts(frame: Option<CloseFrame>) -> (u16, Bytes) {
    frame.map_or((1005, Bytes::new()), |f| {
        (u16::from(f.code), Bytes::from(f.reason))
    })
}

/// The client broke the protocol: send `code` and stop. Its stream is over.
async fn fail_ws<S>(mut ws: WebSocketStream<S>, code: CloseCode) -> (u16, Bytes)
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let frame = CloseFrame {
        code,
        reason: Utf8Bytes::from_static(""),
    };
    let _ = ws.send(Message::Close(Some(frame))).await;
    (u16::from(code), Bytes::new())
}

async fn close_ws<S>(ws: WebSocketStream<S>, code: CloseCode) -> (u16, Bytes)
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let frame = CloseFrame {
        code,
        reason: Utf8Bytes::from_static(""),
    };
    close_ws_with(ws, Some(frame)).await
}

/// Sends a close frame and waits up to [CLOSE_WAIT] for the one of the
/// client. Returns its code, like dart:io does.
async fn close_ws_with<S>(mut ws: WebSocketStream<S>, frame: Option<CloseFrame>) -> (u16, Bytes)
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let _ = ws.send(Message::Close(frame)).await;
    let wait = async {
        while let Some(Ok(m)) = ws.next().await {
            if let Message::Close(f) = m {
                return Some(close_parts(f));
            }
        }
        None
    };
    let got = tokio::time::timeout(CLOSE_WAIT, wait).await.ok().flatten();
    got.unwrap_or((1006, Bytes::new()))
}

/// Adds one WebSocket record (a message or the close) to the batch. The
/// head is the same 44 bytes as a request record.
fn enqueue_ws(ctx: &Ctx, id: u64, kind: u32, code: u16, data: &[u8]) {
    let mut b = ctx.batch.borrow_mut();
    let was_empty = b.is_empty();
    b.extend_from_slice(&id.to_le_bytes());
    b.extend_from_slice(&(kind << 8).to_le_bytes());
    b.extend_from_slice(&[0; 8]); // method, target and headers lengths
    b.extend_from_slice(&(data.len() as u32).to_le_bytes());
    b.extend_from_slice(&code.to_le_bytes());
    b.extend_from_slice(&[0; 18]); // reserved, remote ip
    b.extend_from_slice(data);
    if was_empty {
        ctx.notify.notify_one();
    }
}

/// Reads the whole body. Over `max` bytes it keeps reading (and drops the
/// bytes) up to DRAIN_MAX more, so the client can finish sending and read
/// the 413. Closing at once gives the client a broken pipe instead.
/// No new bytes for `idle` gives 408. A slow but steady upload is fine.
async fn read_body(
    mut body: Incoming,
    max: usize,
    hint: usize,
    idle: Duration,
) -> Result<Vec<u8>, StatusCode> {
    let mut buf = Vec::with_capacity(hint);
    let mut seen = 0usize;
    loop {
        let Ok(frame) = tokio::time::timeout(idle, body.frame()).await else {
            return Err(StatusCode::REQUEST_TIMEOUT);
        };
        let Some(frame) = frame else { break };
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
) -> oneshot::Receiver<Reply> {
    let (tx, rx) = oneshot::channel();
    let id = ctx.pending.borrow_mut().insert(tx) as u64;
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
        // both fit in u16: the whole head is at most MAX_HEAD bytes
        b.extend_from_slice(&(k.as_str().len() as u16).to_le_bytes());
        b.extend_from_slice(&(v.len() as u16).to_le_bytes());
        b.extend_from_slice(k.as_str().as_bytes());
        b.extend_from_slice(v.as_bytes());
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

/// How often an idle server checks that its isolate is still alive.
const PROBE: Duration = Duration::from_millis(100);

/// Posts the batch once all tasks that are ready this tick have added to it.
///
/// When idle, it posts an empty message every [PROBE]. A killed isolate
/// does not call `dox_stop`, so this is how its server finds out and stops.
/// Without it, the dead server keeps its listener (on Linux one of the
/// SO_REUSEPORT sockets) and loses the connections the kernel gives it.
async fn flusher(ctx: Rc<Ctx>, port: i64) {
    let mut out = Vec::new();
    loop {
        let probe = tokio::select! {
            _ = ctx.notify.notified() => false,
            _ = tokio::time::sleep(PROBE) => true,
        };
        if !probe {
            tokio::task::yield_now().await;
            std::mem::swap(&mut out, &mut *ctx.batch.borrow_mut());
            if out.is_empty() {
                continue;
            }
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

/// Hands the answers from Dart to the waiting requests.
async fn deliver(ctx: Rc<Ctx>) {
    let mut answers = Vec::new();
    loop {
        ctx.server.answered.notified().await;
        std::mem::swap(&mut answers, &mut *ctx.server.inbox.lock().unwrap());
        let mut pending = ctx.pending.borrow_mut();
        for out in answers.drain(..) {
            match out {
                Out::Http(id, r, ws) => {
                    let Some(tx) = pending.try_remove(id) else {
                        continue;
                    };
                    // the channel is made here, before later messages of
                    // the same batch need it
                    let accepted = ws.map(|(id, max)| {
                        let (wtx, rx) = unbounded_channel();
                        ctx.sockets.borrow_mut().insert(id, wtx);
                        Accepted { id, max, rx }
                    });
                    if let Err((_, Some(gone))) = tx.send((r, accepted)) {
                        // the client left before the answer
                        ctx.sockets.borrow_mut().remove(&gone.id);
                        enqueue_ws(&ctx, gone.id, WS_CLOSED, 1006, b"");
                    }
                }
                Out::Ws(id, m) => {
                    if let Some(tx) = ctx.sockets.borrow().get(&id) {
                        let _ = tx.send(m);
                    }
                }
            }
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
/// `family`, `addr_hi` and `addr_lo` are the host, see [Key]. Family 0 is
/// all interfaces.
/// Bodies over `max_body` bytes (`max_multipart` for a multipart form) get
/// 413. A body with no new bytes for `body_timeout_ms` gets 408.
/// Returns a handle (> 0), or < 0: -1 not initialized, -(1000 + errno)
/// when the bind fails.
#[unsafe(no_mangle)]
pub extern "C" fn dox_start(
    port: i32,
    send_port: i64,
    max_body: i64,
    max_multipart: i64,
    body_timeout_ms: i64,
    family: i32,
    addr_hi: u64,
    addr_lo: u64,
) -> i64 {
    if POST.get().is_none() {
        return -1;
    }
    let (listener, key) = match bind((family, addr_hi, addr_lo, port as u16)) {
        Ok(l) => l,
        Err(e) => return -(1000 + i64::from(e.raw_os_error().unwrap_or(0))),
    };
    let server = Arc::new(Server::new(key));
    let limits = Limits {
        body: max_body.max(0) as usize,
        multipart: max_multipart.max(0) as usize,
        timeout: Duration::from_millis(body_timeout_ms.max(0) as u64),
    };
    if shared_thread() {
        if !start_shared(listener, server.clone(), send_port, limits) {
            return -2;
        }
        return Arc::into_raw(server) as i64;
    }
    let for_thread = server.clone();
    let thread = std::thread::Builder::new()
        .name("dox-http".into())
        .spawn(move || {
            let rt = new_runtime();
            let local = tokio::task::LocalSet::new();
            local.block_on(&rt, run_server(listener, for_thread, send_port, limits));
            drop(local); // closes what is left (lingering closes)
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

/// Starts a graceful shutdown: the server stops accepting connections at
/// once. Each open connection closes after its current answer. When all
/// are closed, Dart gets a message of one byte. Then call `dox_stop`.
///
/// # Safety
/// `handle` must come from `dox_start` and not be stopped.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn dox_shutdown(handle: i64) {
    let server = unsafe { &*(handle as *const Server) };
    server.drain();
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
    let done = server.done.lock().unwrap().take();
    if let Some(done) = done {
        let _ = done.recv(); // the server ended and freed its port
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
    // One copy of the whole batch. Bodies and header values are slices of
    // it, so there is no copy or allocation per response for them.
    let all = Bytes::copy_from_slice(unsafe { std::slice::from_raw_parts(ptr, len as usize) });
    let b = &all[..];
    let mut p = 0;
    while p + RES_HEAD <= b.len() {
        let id = u64::from_le_bytes(b[p..p + 8].try_into().unwrap());
        let status = rd16(b, p + 8);
        let kind = rd16(b, p + 10);
        let hlen = rd32(b, p + 12);
        let blen = rd32(b, p + 16);
        let h_at = p + RES_HEAD;
        if h_at + hlen + blen > b.len() {
            break; // broken record: drop the rest
        }
        let body_at = h_at + hlen;
        p = body_at + blen;
        let body = all.slice(body_at..p);
        let out = match kind {
            0 | 1 => {
                // an accept has no HTTP body
                let http_body = if kind == 0 {
                    body.clone()
                } else {
                    Bytes::new()
                };
                let r = answer(&all, status, h_at, body_at, http_body);
                // accept: u64 ws id, u64 max message size
                let ws = (kind == 1 && blen >= 16).then(|| {
                    let max = u64::from_le_bytes(body[8..16].try_into().unwrap());
                    (
                        u64::from_le_bytes(body[..8].try_into().unwrap()),
                        max.min(u64::from(u32::MAX)) as usize,
                    )
                });
                Out::Http(id as usize, r, ws)
            }
            2 => match Utf8Bytes::try_from(body) {
                Ok(text) => Out::Ws(id, Message::Text(text)),
                Err(_) => continue, // Dart always sends UTF-8
            },
            3 => Out::Ws(id, Message::Binary(body)),
            4 => {
                let frame = (status != 0).then(|| CloseFrame {
                    code: CloseCode::from(status),
                    reason: Utf8Bytes::try_from(body)
                        .unwrap_or_else(|_| Utf8Bytes::from_static("")),
                });
                Out::Ws(id, Message::Close(frame))
            }
            _ => continue,
        };
        // Wake the server thread on the first answer, so it writes that one
        // while we build the rest. Later ones join the same wake as long as
        // it has not taken the inbox yet.
        let was_empty = {
            let mut inbox = server.inbox.lock().unwrap();
            inbox.push(out);
            inbox.len() == 1
        };
        if was_empty {
            server.answered.notify_one();
        }
    }
}

/// Builds an HTTP answer from a response record. Header values are slices
/// of `all`, not copies.
fn answer(all: &Bytes, status: u16, h_at: usize, body_at: usize, body: Bytes) -> Answer {
    let b = &all[..];
    let mut r = Response::new(Full::new(body));
    *r.status_mut() = StatusCode::from_u16(status).unwrap_or(StatusCode::INTERNAL_SERVER_ERROR);
    let mut at = h_at;
    for line in b[h_at..body_at].split(|&c| c == b'\n') {
        let line_at = at;
        at += line.len() + 1;
        let line = line.strip_suffix(b"\r").unwrap_or(line);
        let Some(colon) = line.iter().position(|&c| c == b':') else {
            continue;
        };
        let value = line[colon + 1..].trim_ascii_start();
        let v_at = line_at + line.len() - value.len();
        let (Ok(k), Ok(v)) = (
            HeaderName::from_bytes(&line[..colon]),
            HeaderValue::from_maybe_shared(all.slice(v_at..v_at + value.len())),
        ) else {
            continue;
        };
        r.headers_mut().append(k, v);
    }
    r
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_limits() -> Limits {
        Limits {
            body: 10,
            multipart: 20,
            timeout: Duration::from_millis(20), // below PROBE
        }
    }

    /// a server with no Dart side. Only for answers that Rust gives itself.
    fn start_bare() -> u16 {
        let (listener, key) = bind((0, 0, 0, 0)).unwrap();
        let port = key.3;
        let server = Arc::new(Server::new(key));
        std::thread::spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .unwrap();
            let local = tokio::task::LocalSet::new();
            let ctx = Rc::new(Ctx::new(server, test_limits()));
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

    /// Sends a 20 byte body (over the limit) in 2 byte parts, 4 ms apart.
    fn slow_send(port: u16) -> String {
        use std::io::{Read, Write};
        let mut s = std::net::TcpStream::connect(("127.0.0.1", port)).unwrap();
        s.set_read_timeout(Some(Duration::from_secs(3))).unwrap();
        s.set_nodelay(true).unwrap();
        s.write_all(b"POST / HTTP/1.1\r\nHost: a\r\nContent-Length: 20\r\n\r\n")
            .unwrap();
        for _ in 0..10 {
            std::thread::sleep(Duration::from_millis(4));
            s.write_all(b"ab").unwrap();
        }
        let mut out = Vec::new();
        let _ = s.read_to_end(&mut out);
        String::from_utf8_lossy(&out).into_owned()
    }

    #[test]
    fn body_limits_and_timeout() {
        // a new server each time: with no Dart side it stops after PROBE
        // too big and the client waits for "100 Continue": 413 at once
        let head = b"POST / HTTP/1.1\r\nHost: a\r\nExpect: 100-continue\r\nContent-Length: 1000000000\r\n\r\n";
        assert!(
            send(start_bare(), head).starts_with("HTTP/1.1 413"),
            "early 413"
        );
        // too big, whole body sent: read and dropped, then 413 (no reset)
        let full = b"POST / HTTP/1.1\r\nHost: a\r\nContent-Length: 15\r\n\r\n123456789012345";
        assert!(send(start_bare(), full).starts_with("HTTP/1.1 413"), "413");
        // slow but steady: 40 ms in all, but never 20 ms without bytes
        let r = slow_send(start_bare());
        assert!(r.starts_with("HTTP/1.1 413"), "steady {r:?}");
        // a stalled body gets 408 after the idle timeout
        let slow = b"POST / HTTP/1.1\r\nHost: a\r\nContent-Length: 5\r\n\r\nab";
        assert!(send(start_bare(), slow).starts_with("HTTP/1.1 408"), "408");
        // a multipart form may be bigger (15 > 10): no 413, it waits for the body
        let form = b"POST / HTTP/1.1\r\nHost: a\r\nContent-Type: multipart/form-data; boundary=x\r\nContent-Length: 15\r\n\r\n";
        assert!(
            send(start_bare(), form).starts_with("HTTP/1.1 408"),
            "multipart limit"
        );
    }

    #[test]
    fn binds_one_host_only() {
        let lo = u64::from(u32::from(Ipv4Addr::LOCALHOST));
        let (listener, key) = bind((4, 0, lo, 0)).unwrap();
        let addr = listener.local_addr().unwrap();
        assert_eq!(addr.ip(), IpAddr::V4(Ipv4Addr::LOCALHOST));
        assert_eq!(key.3, addr.port());
        unbind(key);
    }

    #[test]
    fn peer_is_mapped_ipv6() {
        let p = peer_bytes("1.2.3.4:513".parse().unwrap());
        assert_eq!(&p[10..16], &[0xff, 0xff, 1, 2, 3, 4]);
        assert_eq!(u16::from_le_bytes([p[16], p[17]]), 513);
    }

    #[test]
    fn finds_websocket_upgrades() {
        let req = |version: &str, upgrade: &str| {
            Request::builder()
                .method("GET")
                .header("connection", "keep-alive, Upgrade")
                .header("upgrade", upgrade)
                .header("sec-websocket-version", version)
                .header("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==")
                .body(())
                .unwrap()
        };
        assert!(ws_key(&req("13", "WebSocket")).is_some());
        assert!(ws_key(&req("8", "websocket")).is_none(), "old version");
        assert!(ws_key(&req("13", "h2c")).is_none(), "not websocket");
        let post = Request::post("/").body(()).unwrap();
        assert!(ws_key(&post).is_none());
        // the example of RFC 6455
        assert_eq!(
            derive_accept_key(b"dGhlIHNhbXBsZSBub25jZQ=="),
            "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
        );
    }

    /// Runs `run_ws` (with a max message size of 8) against a client on
    /// an in-memory pipe.
    async fn ws_pair() -> (
        WebSocketStream<tokio::io::DuplexStream>,
        UnboundedSender<Message>,
        Rc<Ctx>,
        tokio::task::JoinHandle<(u16, Bytes)>,
    ) {
        let (a, b) = tokio::io::duplex(1 << 16);
        let ctx = Rc::new(Ctx::new(Arc::new(Server::new((0, 0, 0, 0))), test_limits()));
        let (tx, rx) = unbounded_channel();
        let c = ctx.clone();
        let task = tokio::task::spawn_local(async move { run_ws(a, 7, 8, rx, &c).await });
        let client = WebSocketStream::from_raw_socket(b, Role::Client, None).await;
        (client, tx, ctx, task)
    }

    /// (kind, code, body) of the WebSocket records in the batch
    fn records(ctx: &Ctx) -> Vec<(u32, u16, Vec<u8>)> {
        let b = ctx.batch.borrow();
        let mut out = Vec::new();
        let mut p = 0;
        while p + 44 <= b.len() {
            assert_eq!(u64::from_le_bytes(b[p..p + 8].try_into().unwrap()), 7);
            let kind = rd32(&b, p + 8) as u32 >> 8;
            let len = rd32(&b, p + 20);
            out.push((kind, rd16(&b, p + 24), b[p + 44..p + 44 + len].to_vec()));
            p += 44 + len;
        }
        out
    }

    fn local_test(f: impl std::future::Future<Output = ()>) {
        let rt = new_runtime();
        tokio::task::LocalSet::new().block_on(&rt, f);
    }

    #[test]
    fn websocket_messages_both_ways() {
        local_test(async {
            let (mut client, tx, ctx, task) = ws_pair().await;
            client.send(Message::text("hi")).await.unwrap();
            client.send(Message::binary(vec![1, 2])).await.unwrap();
            client
                .send(Message::Ping(Bytes::from_static(b"p")))
                .await
                .unwrap();
            tx.send(Message::text("back")).unwrap();
            assert_eq!(
                client.next().await.unwrap().unwrap(),
                Message::Pong(Bytes::from_static(b"p"))
            );
            assert_eq!(client.next().await.unwrap().unwrap(), Message::text("back"));
            let frame = CloseFrame {
                code: CloseCode::Normal,
                reason: Utf8Bytes::from_static("bye"),
            };
            client.close(Some(frame)).await.unwrap();
            let (code, reason) = task.await.unwrap();
            assert_eq!((code, &reason[..]), (1000, &b"bye"[..]));
            assert_eq!(
                records(&ctx),
                vec![(WS_TEXT, 0, b"hi".to_vec()), (WS_BINARY, 0, vec![1, 2])]
            );
        });
    }

    #[test]
    fn websocket_too_big_closes_with_1009() {
        local_test(async {
            let (mut client, _tx, _ctx, task) = ws_pair().await;
            client.send(Message::text("123456789")).await.unwrap();
            let Some(Ok(Message::Close(Some(frame)))) = client.next().await else {
                panic!("no close frame");
            };
            assert_eq!(frame.code, CloseCode::Size);
            assert_eq!(task.await.unwrap().0, 1009);
        });
    }

    #[test]
    fn websocket_close_from_dart() {
        local_test(async {
            let (mut client, tx, _ctx, task) = ws_pair().await;
            tx.send(Message::Close(Some(CloseFrame {
                code: CloseCode::from(4000),
                reason: Utf8Bytes::from_static("done"),
            })))
            .unwrap();
            let Some(Ok(Message::Close(Some(frame)))) = client.next().await else {
                panic!("no close frame");
            };
            assert_eq!(u16::from(frame.code), 4000);
            // the client answers the close. Rust reports its code.
            assert!(client.next().await.is_none());
            assert_eq!(task.await.unwrap().0, 4000);
        });
    }
}

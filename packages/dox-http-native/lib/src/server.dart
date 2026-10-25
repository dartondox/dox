import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dox_http_native/src/bindings.dart';
import 'package:dox_http_native/src/headers.dart';
import 'package:dox_http_native/src/request.dart';
import 'package:dox_http_native/src/response.dart';
import 'package:dox_http_native/src/websocket.dart';

/// An [HttpServer] where Rust (hyper) owns the sockets and parses HTTP.
/// Handlers run in Dart, like with `dart:io`.
///
/// ```
/// NativeHttpServer server = await NativeHttpServer.bind(3000);
/// server.listen((HttpRequest req) {
///   req.response.write('Hello World');
///   req.response.close();
/// });
/// ```
///
/// Each isolate can bind the same port. The OS shares the connections
/// between them (`SO_REUSEPORT` on Linux and macOS).
class NativeHttpServer extends Stream<HttpRequest> implements HttpServer {
  NativeHttpServer._(this._handle, this._receive, this.port, this.address);

  static bool? _available;
  static String? _loadError;

  /// true when the native library is loaded and works.
  static bool get isAvailable => _available ??= _load();

  /// why [isAvailable] is false, or null.
  static String? get loadError {
    isAvailable;
    return _loadError;
  }

  /// Throws an [UnsupportedError] that says why the native library did not
  /// load and how to fix it. Does nothing when it loaded.
  static void ensureAvailable() {
    if (isAvailable) return;
    throw UnsupportedError(
      'dox_http_native did not load: $_loadError.\n'
      'Fix: install Rust (cargo, see https://rustup.rs), then run the app '
      'again with `dart run` or `dart build cli`. The build hook then builds '
      'the library from source. When you set `lib_path` in pubspec.yaml, '
      'rebuild that library: `cargo build --release` in '
      'packages/dox-http-native/native.',
    );
  }

  static bool _load() {
    try {
      int version = doxVersion();
      if (version != abiVersion) {
        _loadError = 'native library ABI $version, expected $abiVersion';
        return false;
      }
      int rc = doxInit(NativeApi.initializeApiDLData);
      if (rc != 0) {
        _loadError = 'dox_init failed ($rc)';
        return false;
      }
      return true;
    } catch (error) {
      // the build hook found no library for this platform
      _loadError = '$error';
      return false;
    }
  }

  /// Listen on [port]. With no [address] it listens on all interfaces
  /// (IPv6 and IPv4). [address] is an [InternetAddress] or a host name
  /// like `127.0.0.1` or `localhost`, the same as `HttpServer.bind`.
  /// Bodies bigger than [maxBodySize] bytes get 413 from Rust. A
  /// multipart form (`multipart/form-data`) may be up to
  /// [maxMultipartSize] bytes instead (default: [maxBodySize]). A body
  /// with a bigger `Content-Length` and `Expect: 100-continue` gets 413
  /// before it is sent. Any other too big body is read and dropped first,
  /// so the client sees the 413 and not a reset.
  /// A client that sends no body bytes for [bodyTimeout] (idle time) gets
  /// 408. A slow but steady upload is fine.
  static Future<NativeHttpServer> bind(
    int port, {
    Object? address,
    int maxBodySize = 100 * 1024 * 1024,
    int? maxMultipartSize,
    Duration bodyTimeout = const Duration(seconds: 120),
  }) async {
    ensureAvailable();
    InternetAddress? ip = await _resolve(address);
    List<int> raw = ip?.rawAddress ?? const <int>[];
    int family = ip == null ? 0 : (raw.length == 4 ? 4 : 6);
    int hi = 0, lo = 0;
    for (int i = 0; i < raw.length; i++) {
      if (raw.length == 16 && i < 8) {
        hi = (hi << 8) | raw[i];
      } else {
        lo = (lo << 8) | raw[i];
      }
    }
    late NativeHttpServer server;
    RawReceivePort receive = RawReceivePort((Object? msg) {
      if (msg is Uint8List) return server._onBatch(msg, const <Object?>[]);
      // a batch with big bodies: [batch, body, body, ...]
      List<Object?> parts = msg as List<Object?>;
      server._onBatch(parts[0] as Uint8List, parts);
    }, 'dox_http_native');
    int handle = doxStart(
      port,
      receive.sendPort.nativePort,
      maxBodySize,
      maxMultipartSize ?? maxBodySize,
      bodyTimeout.inMilliseconds,
      family,
      hi,
      lo,
    );
    if (handle <= 0) {
      receive.close();
      int code = handle <= -1000 ? -(handle + 1000) : 0;
      throw SocketException(
        'dox_http_native: bind failed ($handle)',
        osError: OSError('', code),
        address: ip,
        port: port,
      );
    }
    server = NativeHttpServer._(
      handle,
      receive,
      doxPort(handle),
      ip ?? InternetAddress.anyIPv6,
    );
    return server;
  }

  /// null for all interfaces. A host name gives its first address.
  static Future<InternetAddress?> _resolve(Object? address) async {
    if (address == null) return null;
    if (address is InternetAddress) return address;
    String host = address.toString();
    InternetAddress? ip = InternetAddress.tryParse(host);
    if (ip != null) return ip;
    List<InternetAddress> found = await InternetAddress.lookup(host);
    return found.first;
  }

  int _handle;
  final RawReceivePort _receive;

  /// open WebSockets of this server, by ws id
  final Map<int, NativeWebSocket> sockets = <int, NativeWebSocket>{};

  /// the id of the next WebSocket
  int nextSocketId = 1;

  /// responses that send their body in parts, by stream id
  final Map<int, NativeResponse> streams = <int, NativeResponse>{};
  int _nextStreamId = 1;
  final StreamController<HttpRequest> _requests = StreamController<HttpRequest>(
    sync: true,
  );

  @override
  final int port;

  @override
  final InternetAddress address;

  @override
  bool autoCompress = false;

  // ponytail: idle keep-alive is not cut by this value. hyper closes a
  // connection that sends no headers for 30 seconds.
  @override
  Duration? idleTimeout = const Duration(seconds: 120);

  @override
  String? get serverHeader => _serverHeader;
  String? _serverHeader;

  @override
  set serverHeader(String? value) {
    _serverHeader = value == null ? null : checkHeaderValue(value);
  }

  @override
  set sessionTimeout(int timeout) {}

  /// same defaults as dart:io
  @override
  final NativeHeaders defaultResponseHeaders = NativeHeaders.empty()
    ..set(HttpHeaders.contentTypeHeader, 'text/plain; charset=utf-8')
    ..set('x-frame-options', 'SAMEORIGIN')
    ..set('x-content-type-options', 'nosniff')
    ..set('x-xss-protection', '1; mode=block');

  @override
  HttpConnectionsInfo connectionsInfo() => HttpConnectionsInfo();

  @override
  StreamSubscription<HttpRequest> listen(
    void Function(HttpRequest event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _requests.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  Completer<void>? _drained;

  /// Stop listening. Like `dart:io`, open requests still get their answer.
  /// Each connection closes after its current answer, and the future
  /// completes when all are closed. With [force] every connection closes
  /// at once, also when a graceful close still waits.
  @override
  Future<void> close({bool force = false}) async {
    if (_handle == 0) return;
    if (!force) {
      Completer<void>? drained = _drained;
      if (drained == null) {
        drained = _drained = Completer<void>();
        doxShutdown(_handle);
      }
      await drained.future;
    }
    if (_handle != 0) {
      doxStop(_handle);
      _handle = 0;
      _receive.close();
      // not awaited: with no listener the close future never completes
      unawaited(_requests.close());
      // Rust is gone, so no close record comes any more
      for (NativeWebSocket ws in List<NativeWebSocket>.of(sockets.values)) {
        ws.closed(WebSocketStatus.abnormalClosure, '');
      }
      // and no stream gets room to send any more
      for (NativeResponse res in List<NativeResponse>.of(streams.values)) {
        res.streamed(-1);
      }
      streams.clear();
      _done();
    }
  }

  void _done() {
    Completer<void>? drained = _drained;
    if (drained != null && !drained.isCompleted) drained.complete();
  }

  // ---- requests from Rust ----

  bool _inBatch = false;

  /// [parts] holds the big bodies from index 1, in the order of the
  /// records that have flag bit 2.
  void _onBatch(Uint8List b, List<Object?> parts) {
    if (b.isEmpty) return; // a probe from Rust: "is this isolate alive?"
    if (b.length == 1) return _done(); // a graceful close is done
    ByteData d = ByteData.sublistView(b);
    int p = 0;
    int nextPart = 1;
    // bytes of WebSocket messages in this batch, acknowledged at the end
    int wsBytes = 0;
    _inBatch = true;
    try {
      while (p + 28 <= b.length) {
        int id = d.getUint64(p, Endian.little);
        int flags = d.getUint32(p + 8, Endian.little);
        int mlen = d.getUint16(p + 12, Endian.little);
        int tlen = d.getUint16(p + 14, Endian.little);
        int hlen = d.getUint32(p + 16, Endian.little);
        int blen = d.getUint32(p + 20, Endian.little);
        int remotePort = d.getUint16(p + 24, Endian.little);
        int q = p + 28;
        Uint8List ip = Uint8List.sublistView(b, q, q + 16);
        q += 16;
        String method = _method(b, q, mlen);
        q += mlen;
        String target = String.fromCharCodes(b, q, q + tlen);
        q += tlen;
        Uint8List headers = Uint8List.sublistView(b, q, q + hlen);
        q += hlen;
        Uint8List body = flags & 4 == 4
            ? parts[nextPart++] as Uint8List
            : Uint8List.sublistView(b, q, q + blen);
        p = q + blen;
        int kind = (flags >> 8) & 0xff;
        if (kind == 4 || kind == 5) {
          // a streamed body: bytes sent to the client, or the client left
          NativeResponse? res = streams[id];
          if (kind == 5) streams.remove(id);
          res?.streamed(kind == 4 ? d.getUint64(q, Endian.little) : -1);
          continue;
        }
        if (kind != 0) {
          // a WebSocket message or close. The port field is the close code.
          if (kind != 3) wsBytes += blen;
          sockets[id]?.receive(kind, remotePort, body);
          continue;
        }
        _requests.add(
          NativeRequest(
            this,
            id,
            method,
            target,
            headers,
            body,
            ip,
            remotePort,
            http10: flags & 1 == 1,
            isWebSocketUpgrade: flags & 2 == 2,
          ),
        );
      }
    } finally {
      // Rust stops reading WebSocket frames while Dart is too far behind
      if (wsBytes > 0) {
        sendWebSocket(wsBytes, NativeWebSocket.kindAck, 0, const <int>[]);
      }
      _inBatch = false;
      _flush();
    }
  }

  static String _method(Uint8List b, int at, int len) {
    // the common ones without a new String
    if (len == 3 && b[at] == 71) return 'GET';
    if (len == 4 && b[at] == 80 && b[at + 1] == 79) return 'POST';
    if (len == 3 && b[at] == 80) return 'PUT';
    if (len == 6 && b[at] == 68) return 'DELETE';
    return String.fromCharCodes(b, at, at + len);
  }

  // ---- responses to Rust ----

  Uint8List _out = Uint8List(1 << 16);
  late ByteData _outData = ByteData.sublistView(_out);
  int _len = 0;
  bool _flushQueued = false;

  Uint8List _defaultLines = Uint8List(0);
  int _defaultVersion = -1;

  void _ensure(int extra) {
    int need = _len + extra;
    if (need <= _out.length) return;
    int size = _out.length * 2;
    while (size < need) {
      size *= 2;
    }
    Uint8List grown = Uint8List(size)..setRange(0, _len, _out);
    _out = grown;
    _outData = ByteData.sublistView(grown);
  }

  void _line(String name, String value) {
    if (name == HttpHeaders.contentLengthHeader ||
        name == HttpHeaders.transferEncodingHeader) {
      return; // Rust sets these from the body
    }
    _ensure(name.length + value.length + 4);
    Uint8List o = _out;
    int at = _len;
    for (int i = 0; i < name.length; i++) {
      o[at++] = name.codeUnitAt(i);
    }
    o[at++] = 58;
    o[at++] = 32;
    for (int i = 0; i < value.length; i++) {
      o[at++] = value.codeUnitAt(i);
    }
    o[at++] = 13;
    o[at++] = 10;
    _len = at;
  }

  Uint8List _defaults() {
    NativeHeaders h = defaultResponseHeaders;
    if (h.version != _defaultVersion) {
      BytesBuilder sb = BytesBuilder();
      h.forEachLine((String name, String value) {
        sb.add('$name: $value\r\n'.codeUnits);
      });
      _defaultLines = sb.takeBytes();
      _defaultVersion = h.version;
    }
    return _defaultLines;
  }

  ContentType? _typedFor;
  Uint8List _typedLines = Uint8List(0);
  int _typedVersion = -1;

  /// the default header lines with another content type. Cached for the
  /// last type, as most apps answer with one type (eg. JSON).
  Uint8List _typed(ContentType type) {
    NativeHeaders h = defaultResponseHeaders;
    if (!identical(type, _typedFor) || h.version != _typedVersion) {
      BytesBuilder sb = BytesBuilder();
      h.forEachLine((String name, String value) {
        if (name == HttpHeaders.contentTypeHeader) return;
        sb.add('$name: $value\r\n'.codeUnits);
      });
      sb.add('${HttpHeaders.contentTypeHeader}: $type\r\n'.codeUnits);
      _typedLines = sb.takeBytes();
      _typedFor = type;
      _typedVersion = h.version;
    }
    return _typedLines;
  }

  /// Starts a record: the 20 byte head. Header lines may follow, then
  /// [_endRecord] adds the body.
  int _startRecord(int id, int status, int kind) {
    _ensure(20);
    int start = _len;
    _outData.setUint64(start, id, Endian.little);
    _outData.setUint16(start + 8, status, Endian.little);
    _outData.setUint16(start + 10, kind, Endian.little);
    _len += 20;
    return start;
  }

  /// Ends the record that starts at [start]. [streamId] goes before the
  /// body (a streamed answer).
  void _endRecord(int start, List<int> body, [int? streamId]) {
    int extra = streamId == null ? 0 : 8;
    _outData.setUint32(start + 12, _len - start - 20, Endian.little);
    _outData.setUint32(start + 16, body.length + extra, Endian.little);
    _ensure(body.length + extra);
    if (streamId != null) {
      _outData.setUint64(_len, streamId, Endian.little);
      _len += 8;
    }
    _out.setRange(_len, _len + body.length, body);
    _len += body.length;
    _queueFlush();
  }

  void _headerLines(NativeResponse res) {
    NativeHeaders headers = res.headers;
    ContentType? type = headers.sharedType;
    Uint8List? lines = headers.isShared
        ? _defaults()
        : (type == null ? null : _typed(type));
    if (lines != null) {
      _ensure(lines.length);
      _out.setRange(_len, _len + lines.length, lines);
      _len += lines.length;
    } else {
      headers.forEachLine(_line);
    }
    String? server = serverHeader;
    if (server != null) _line(HttpHeaders.serverHeader, server);
    if (res.hasCookies) {
      for (Cookie cookie in res.cookies) {
        _line(HttpHeaders.setCookieHeader, cookie.toString());
      }
    }
  }

  /// Queue the response of [req]. Sent at the end of the batch, or in a
  /// microtask when the handler answered later.
  void send(NativeRequest req, NativeResponse res) {
    if (_handle == 0) return;
    List<int> body = res.takeBody();
    // kind bit 8: Rust gzips the body, off this isolate
    bool zip = autoCompress && body.length > 256 && _gzip(req, res);
    int start = _startRecord(req.id, res.statusCode, zip ? 0x100 : 0);
    _headerLines(res);
    _endRecord(start, body);
  }

  /// Starts the answer of [req] with a body in parts. [first] is the first
  /// part. Returns the stream id for [sendPart] and [endStream].
  int startStream(NativeRequest req, NativeResponse res, List<int> first) {
    int id = _nextStreamId++;
    if (_handle == 0) return id;
    streams[id] = res;
    int start = _startRecord(req.id, res.statusCode, 6);
    _headerLines(res);
    // Rust drops the content-length line of a full body. Here it is the
    // only way the client knows the length up front.
    int length = res.headers.contentLength;
    if (length >= 0) _lengthLine(length);
    _endRecord(start, first, id);
    return id;
  }

  void _lengthLine(int length) {
    List<int> line =
        '${HttpHeaders.contentLengthHeader}: $length\r\n'.codeUnits;
    _ensure(line.length);
    _out.setRange(_len, _len + line.length, line);
    _len += line.length;
  }

  /// Queue one part of the streamed body [id].
  void sendPart(int id, List<int> data) {
    if (_handle == 0 || data.isEmpty) return;
    _endRecord(_startRecord(id, 0, 7), data);
  }

  /// Ends the streamed body [id]. When not [ok], Rust cuts the connection,
  /// so the client sees the body is not whole.
  void endStream(int id, {bool ok = true}) {
    streams.remove(id);
    if (_handle == 0) return;
    _endRecord(_startRecord(id, ok ? 0 : 1, 8), const <int>[]);
  }

  /// Queue a WebSocket record for Rust: an accept of the request [id], or
  /// a message for the WebSocket [id]. [kind] and [status] are the fields
  /// of the response record, see `NativeWebSocket`.
  void sendWebSocket(
    int id,
    int kind,
    int status,
    List<int> body, {
    String? protocol,
  }) {
    if (_handle == 0) return;
    int start = _startRecord(id, status, kind);
    if (protocol != null) _line('sec-websocket-protocol', protocol);
    _endRecord(start, body);
  }

  void _queueFlush() {
    if (!_inBatch && !_flushQueued) {
      _flushQueued = true;
      scheduleMicrotask(_flush);
    }
  }

  /// true when the client takes gzip and the body is not encoded yet.
  /// Then it sets `content-encoding` and Rust gzips the body.
  bool _gzip(NativeRequest req, NativeResponse res) {
    String? accept = req.headers.value(HttpHeaders.acceptEncodingHeader);
    if (accept == null || !accept.contains('gzip')) return false;
    if (res.headers.value(HttpHeaders.contentEncodingHeader) != null) {
      return false;
    }
    res.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
    return true;
  }

  void _flush() {
    _flushQueued = false;
    if (_len == 0 || _handle == 0) return;
    doxRespondBatch(_handle, _out.address, _len);
    _len = 0;
    if (_out.length > 1 << 20) {
      _out = Uint8List(1 << 16); // do not keep a big body buffer forever
      _outData = ByteData.sublistView(_out);
    }
  }
}

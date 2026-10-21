import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dox_http_native/src/bindings.dart';
import 'package:dox_http_native/src/headers.dart';
import 'package:dox_http_native/src/request.dart';
import 'package:dox_http_native/src/response.dart';

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
  NativeHttpServer._(this._handle, this._receive, this.port);

  static bool? _available;
  static String? _loadError;

  /// true when the native library is loaded and works.
  static bool get isAvailable => _available ??= _load();

  /// why [isAvailable] is false, or null.
  static String? get loadError {
    isAvailable;
    return _loadError;
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

  /// Listen on [port] on all interfaces (IPv6 and IPv4).
  /// Bodies bigger than [maxBodySize] bytes get 413 from Rust.
  static Future<NativeHttpServer> bind(
    int port, {
    int maxBodySize = 100 * 1024 * 1024,
  }) async {
    if (!isAvailable) {
      throw UnsupportedError('dox_http_native is not available: $_loadError');
    }
    late NativeHttpServer server;
    RawReceivePort receive = RawReceivePort((Object? msg) {
      server._onBatch(msg as Uint8List);
    }, 'dox_http_native');
    int handle = doxStart(port, receive.sendPort.nativePort, maxBodySize);
    if (handle <= 0) {
      receive.close();
      int code = handle <= -1000 ? -(handle + 1000) : 0;
      throw SocketException(
        'dox_http_native: bind failed ($handle)',
        osError: OSError('', code),
        port: port,
      );
    }
    server = NativeHttpServer._(handle, receive, doxPort(handle));
    return server;
  }

  int _handle;
  final RawReceivePort _receive;
  final StreamController<HttpRequest> _requests = StreamController<HttpRequest>(
    sync: true,
  );

  @override
  final int port;

  @override
  InternetAddress get address => InternetAddress.anyIPv6;

  @override
  bool autoCompress = false;

  // ponytail: idle keep-alive is not cut by this value. hyper closes a
  // connection that sends no headers for 30 seconds.
  @override
  Duration? idleTimeout = const Duration(seconds: 120);

  @override
  String? serverHeader;

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

  /// Stop listening and close every connection.
  @override
  Future<void> close({bool force = false}) async {
    if (_handle != 0) {
      doxStop(_handle);
      _handle = 0;
      _receive.close();
      await _requests.close();
    }
  }

  // ---- requests from Rust ----

  bool _inBatch = false;

  void _onBatch(Uint8List b) {
    if (b.isEmpty) return; // a probe from Rust: "is this isolate alive?"
    ByteData d = ByteData.sublistView(b);
    int p = 0;
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
        Uint8List body = Uint8List.sublistView(b, q, q + blen);
        p = q + blen;
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
          ),
        );
      }
    } finally {
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

  /// Queue the response of [req]. Sent at the end of the batch, or in a
  /// microtask when the handler answered later.
  void send(NativeRequest req, NativeResponse res) {
    if (_handle == 0) return;
    List<int> body = res.takeBody();
    if (autoCompress && body.length > 256) body = _gzip(req, res, body);
    _ensure(20);
    int start = _len;
    _outData.setUint64(start, req.id, Endian.little);
    _outData.setUint16(start + 8, res.statusCode, Endian.little);
    _outData.setUint16(start + 10, 0, Endian.little);
    _len += 20;
    NativeHeaders headers = res.headers;
    if (headers.isShared) {
      Uint8List lines = _defaults();
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
    _outData.setUint32(start + 12, _len - start - 20, Endian.little);
    _outData.setUint32(start + 16, body.length, Endian.little);
    _ensure(body.length);
    _out.setRange(_len, _len + body.length, body);
    _len += body.length;
    if (!_inBatch && !_flushQueued) {
      _flushQueued = true;
      scheduleMicrotask(_flush);
    }
  }

  List<int> _gzip(NativeRequest req, NativeResponse res, List<int> body) {
    String? accept = req.headers.value(HttpHeaders.acceptEncodingHeader);
    if (accept == null || !accept.contains('gzip')) return body;
    if (res.headers.value(HttpHeaders.contentEncodingHeader) != null) {
      return body;
    }
    res.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
    return gzip.encode(body);
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

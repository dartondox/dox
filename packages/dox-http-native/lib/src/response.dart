import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_http_native/src/headers.dart';
import 'package:dox_http_native/src/request.dart';

/// [HttpResponse] for the native server.
///
/// A small body is kept in memory and sent to Rust in one piece on
/// [close]. When [addStream] passes [streamAt] bytes, the answer starts and
/// the body goes out in parts. At most [window] bytes wait in Rust, so a
/// big file never sits in memory and the client gets data early.
class NativeResponse implements HttpResponse {
  NativeResponse(this._request)
    : headers = NativeHeaders.response(_request.server.defaultResponseHeaders);

  final NativeRequest _request;

  @override
  final NativeHeaders headers;

  @override
  int statusCode = HttpStatus.ok;

  @override
  String reasonPhrase = '';

  @override
  bool bufferOutput = true;

  @override
  Duration? deadline;

  List<Cookie>? _cookies;

  @override
  List<Cookie> get cookies => _cookies ??= <Cookie>[];
  bool _closed = false;
  Completer<HttpResponse>? _done;
  Encoding? _encoding;

  List<int>? _first;
  BytesBuilder? _more;
  int _size = 0;

  /// [addStream] starts a streamed answer from this many body bytes
  static const int streamAt = 64 * 1024;

  /// most bytes given to Rust and not yet sent to the client
  static const int window = 1024 * 1024;

  /// the stream id, once the body goes out in parts
  int? _stream;
  int _unsent = 0;
  Completer<void>? _room;
  bool _gone = false;

  /// true after [close]
  bool get isClosed => _closed;

  /// the body, all chunks together
  List<int> takeBody() {
    BytesBuilder? more = _more;
    List<int> body = more != null ? more.takeBytes() : _first ?? const <int>[];
    _first = null;
    _more = null;
    _size = 0;
    return body;
  }

  /// Rust sent [bytes] of the streamed body to the client. -1: the client
  /// is gone, stop sending.
  void streamed(int bytes) {
    if (bytes < 0) {
      _gone = true;
    } else {
      _unsent -= bytes;
    }
    Completer<void>? room = _room;
    if (room != null && (_gone || _unsent <= window)) {
      _room = null;
      room.complete();
    }
  }

  /// Marks the response as sent: a WebSocket accept answers the request.
  void upgraded() {
    _closed = true;
    _done?.complete(this);
  }

  /// true when a cookie was added
  bool get hasCookies => _cookies?.isNotEmpty ?? false;

  @override
  int get contentLength => headers.contentLength;

  @override
  set contentLength(int length) => headers.contentLength = length;

  @override
  bool get persistentConnection => headers.persistentConnection;

  @override
  set persistentConnection(bool keep) => headers.persistentConnection = keep;

  @override
  HttpConnectionInfo? get connectionInfo => _request.connectionInfo;

  @override
  Encoding get encoding {
    Encoding? set = _encoding;
    if (set != null) return set;
    if (headers.isShared) return utf8; // default text/plain; charset=utf-8
    String? charset = headers.contentType?.charset;
    if (charset == null) return latin1;
    return Encoding.getByName(charset) ?? latin1;
  }

  @override
  set encoding(Encoding value) => _encoding = value;

  @override
  void add(List<int> data) {
    if (_closed) throw StateError('StreamSink is closed');
    if (data.isEmpty) return;
    int? stream = _stream;
    if (stream != null) {
      if (_gone) return;
      _request.server.sendPart(stream, data);
      _unsent += data.length;
      return;
    }
    _size += data.length;
    if (_first == null) {
      _first = data;
      return;
    }
    BytesBuilder more = _more ??= (BytesBuilder(copy: false)..add(_first!));
    more.add(data);
  }

  @override
  void write(Object? object) {
    String text = '$object';
    if (text.isNotEmpty) add(encoding.encode(text));
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeln([Object? object = '']) => write('$object\n');

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _done?.completeError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    try {
      await for (List<int> chunk in stream) {
        add(chunk);
        if (_stream == null && _size >= streamAt) _startStream();
        // wait while Rust holds a full window, so memory stays small
        if (_unsent > window) await (_room = Completer<void>()).future;
        if (_gone) break; // the client left: stop reading the source
      }
    } catch (_) {
      int? id = _stream;
      if (id != null && !_closed) {
        // the head is sent: cut the connection, the body is not whole
        _closed = true;
        _request.server.endStream(id, ok: false);
        _done?.complete(this);
      }
      rethrow;
    }
  }

  /// Sends the head and the body so far. Later parts go out at once.
  void _startStream() {
    _checkCookies();
    List<int> first = takeBody();
    _stream = _request.server.startStream(_request, this, first);
    _unsent += first.length;
  }

  /// Cookie does not check its domain, so a line break there would add a
  /// header. Check before the head is sent.
  void _checkCookies() {
    if (!hasCookies) return;
    for (Cookie cookie in cookies) {
      checkHeaderValue(cookie.toString());
    }
  }

  @override
  Future<void> flush() => Future<void>.value();

  @override
  Future<HttpResponse> close() {
    if (!_closed) {
      int? stream = _stream;
      // checked before the response is marked closed
      if (stream == null) _checkCookies();
      _closed = true;
      if (stream == null) {
        _request.server.send(_request, this);
      } else {
        _request.server.endStream(stream);
      }
      _done?.complete(this);
    }
    return done;
  }

  @override
  Future<HttpResponse> get done {
    if (_closed && _done == null) return Future<HttpResponse>.value(this);
    return (_done ??= Completer<HttpResponse>()).future;
  }

  @override
  Future<void> redirect(
    Uri location, {
    int status = HttpStatus.movedTemporarily,
  }) {
    statusCode = status;
    headers.set(HttpHeaders.locationHeader, location.toString());
    return close();
  }

  @override
  Future<Socket> detachSocket({bool writeHeaders = true}) {
    // Rust owns the socket. For a WebSocket use `NativeWebSocket.upgrade`.
    throw UnsupportedError(
      'dox_http_native can not detach the socket. '
      'Use NativeWebSocket.upgrade for a WebSocket.',
    );
  }
}

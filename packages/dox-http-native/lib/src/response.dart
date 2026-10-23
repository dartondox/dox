import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_http_native/src/headers.dart';
import 'package:dox_http_native/src/request.dart';

/// [HttpResponse] for the native server.
///
/// The body is kept in memory and sent to Rust in one piece on [close].
// ponytail: no streaming to the socket yet. A big file is held in memory
// until close. Add chunk records with flow control when that matters.
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

  /// true after [close]
  bool get isClosed => _closed;

  /// the body, all chunks together
  List<int> takeBody() {
    BytesBuilder? more = _more;
    if (more != null) return more.takeBytes();
    return _first ?? const <int>[];
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
    await for (List<int> chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> flush() => Future<void>.value();

  @override
  Future<HttpResponse> close() {
    if (!_closed) {
      // Cookie does not check its domain, so a line break there would add
      // a header. Check before the response is marked closed.
      if (hasCookies) {
        for (Cookie cookie in cookies) {
          checkHeaderValue(cookie.toString());
        }
      }
      _closed = true;
      _request.server.send(_request, this);
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
    // TODO(native): WebSocket upgrade. Dox uses dart:io for apps with
    // WebSocket or Socket.IO routes until this works.
    throw UnsupportedError('dox_http_native can not detach the socket');
  }
}

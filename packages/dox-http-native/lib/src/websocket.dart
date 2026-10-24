import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_http_native/src/headers.dart';
import 'package:dox_http_native/src/request.dart';
import 'package:dox_http_native/src/server.dart';

/// A WebSocket on the native server.
///
/// How it works:
/// - Rust marks a request that can upgrade (GET, HTTP/1.1, `Upgrade:
///   websocket`, version 13, a key). Dart runs routing, middleware and the
///   Origin check like for any request.
/// - [upgrade] accepts it. Rust sends the `101` answer and then speaks the
///   WebSocket protocol: ping and pong, the close handshake, the UTF-8
///   check of text and the size limit. A message or frame over
///   `maxMessageSize` bytes closes the socket with 1009. Compression
///   (permessage-deflate) is never agreed.
/// - Dart gets whole messages, through the same batches as requests: a
///   [String] for text, a [Uint8List] for binary. While Dart is far behind
///   (8 MiB of messages not handled), Rust stops reading from clients.
/// - Messages to a client wait in a queue until it reads them. Over 4 times
///   `maxMessageSize` (at least 1 MiB) the socket closes with 1008 (policy
///   violation). A message that can not be sent in 30 seconds, or a close
///   handshake that does not finish in 5 seconds, drops the socket (1006).
///
/// It implements the `dart:io` [WebSocket] API, so code written for
/// `WebSocketTransformer.upgrade` works the same.
///
/// ```
/// server.listen((HttpRequest req) async {
///   WebSocket ws = await NativeWebSocket.upgrade(req);
///   ws.listen((dynamic message) => ws.add('echo: $message'));
/// });
/// ```
class NativeWebSocket extends Stream<dynamic> implements WebSocket {
  NativeWebSocket._(this._server, this._id, this.protocol);

  /// true when [request] asks for a WebSocket upgrade.
  static bool isUpgradeRequest(HttpRequest request) {
    if (request is NativeRequest) return request.isWebSocketUpgrade;
    return WebSocketTransformer.isUpgradeRequest(request);
  }

  /// Accepts the WebSocket upgrade of [request]. [protocol] is the
  /// subprotocol to answer with (`Sec-WebSocket-Protocol`), if any. A
  /// message or frame over [maxMessageSize] bytes closes the socket with
  /// 1009 before Dart gets it.
  ///
  /// A request that is not an upgrade gets 400 and the future fails with a
  /// [WebSocketException], like `WebSocketTransformer.upgrade`.
  ///
  /// A request of a plain `dart:io` server is upgraded by `dart:io`, with
  /// compression off. There [maxMessageSize] is not checked.
  static Future<WebSocket> upgrade(
    HttpRequest request, {
    String? protocol,
    int maxMessageSize = 16 * 1024 * 1024,
  }) async {
    if (request is! NativeRequest) {
      return WebSocketTransformer.upgrade(
        request,
        protocolSelector: protocol == null
            ? null
            : (List<String> _) => protocol,
        compression: CompressionOptions.compressionOff,
      );
    }
    if (protocol != null) checkHeaderValue(protocol);
    if (!request.isWebSocketUpgrade) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      throw WebSocketException('Invalid WebSocket upgrade request');
    }
    NativeHttpServer server = request.server;
    NativeWebSocket ws = NativeWebSocket._(
      server,
      server.nextSocketId++,
      protocol,
    );
    server.sockets[ws._id] = ws;
    request.response.upgraded();
    ByteData body = ByteData(16)
      ..setUint64(0, ws._id, Endian.little)
      ..setUint64(8, maxMessageSize, Endian.little);
    server.sendWebSocket(
      request.id,
      kindAccept,
      HttpStatus.switchingProtocols,
      body.buffer.asUint8List(),
      protocol: protocol,
    );
    return ws;
  }

  /// Record kinds from Dart to Rust (the kind field of a response record).
  static const int kindAccept = 1;
  static const int kindText = 2;
  static const int kindBinary = 3;
  static const int kindClose = 4;

  /// Dart handled this many bytes (the id field) of client messages.
  static const int kindAck = 5;

  final NativeHttpServer _server;
  final int _id;
  final StreamController<dynamic> _messages = StreamController<dynamic>();
  final Completer<void> _done = Completer<void>();
  int _state = WebSocket.open;
  int? _closeCode;
  String? _closeReason;

  @override
  final String? protocol;

  /// Always empty: no extension (like compression) is agreed.
  @override
  String get extensions => '';

  @override
  int get readyState => _state;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  // ponytail: Rust answers the pings of the client, but sends none itself.
  // Add a ping record when a server side keep-alive is needed.
  @override
  Duration? pingInterval;

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _messages.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// Sends a [String] as a text message, a `List<int>` as binary. After
  /// [close], or once the socket is closed, the message is dropped.
  @override
  void add(dynamic data) {
    if (data is String) {
      _send(kindText, utf8.encode(data));
    } else if (data is List<int>) {
      _send(kindBinary, data);
    } else {
      throw ArgumentError.value(data, 'data', 'must be a String or List<int>');
    }
  }

  /// Sends [bytes] (UTF-8) as a text message. Rust drops a message that is
  /// not valid UTF-8.
  @override
  void addUtf8Text(List<int> bytes) => _send(kindText, bytes);

  /// An error is not sent to the client, like `dart:io`.
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (dynamic data in stream) {
      add(data);
    }
  }

  /// Starts the close handshake with [code] and [reason]. The future
  /// completes when the socket is closed.
  @override
  Future<void> close([int? code, String? reason]) {
    if (_reserved(code)) {
      throw WebSocketException('Reserved status code $code');
    }
    List<int> text = utf8.encode(reason ?? '');
    if (text.length > 123) {
      throw WebSocketException('Reason is longer than 123 bytes');
    }
    if (_state == WebSocket.open) {
      _state = WebSocket.closing;
      _server.sendWebSocket(_id, kindClose, code ?? 0, text);
    }
    return done;
  }

  @override
  Future<void> get done => _done.future;

  void _send(int kind, List<int> data) {
    if (_state != WebSocket.open) return;
    _server.sendWebSocket(_id, kind, 0, data);
  }

  /// A record from Rust: 1 text, 2 binary, 3 closed (with [code]).
  void receive(int kind, int code, Uint8List body) {
    if (kind == 1) {
      _messages.add(utf8.decode(body));
    } else if (kind == 2) {
      _messages.add(Uint8List.fromList(body));
    } else {
      closed(code, utf8.decode(body, allowMalformed: true));
    }
  }

  /// The socket is closed: Rust said so, or the server stopped.
  void closed(int code, String reason) {
    if (_state == WebSocket.closed) return;
    _state = WebSocket.closed;
    _closeCode = code;
    _closeReason = reason;
    _server.sockets.remove(_id);
    // not awaited: with no listener the close future never completes
    unawaited(_messages.close());
    _done.complete();
  }

  /// Codes a server may not send, the same as `dart:io`.
  static bool _reserved(int? code) {
    return code != null &&
        (code < WebSocketStatus.normalClosure ||
            code == WebSocketStatus.reserved1004 ||
            code == WebSocketStatus.noStatusReceived ||
            code == WebSocketStatus.abnormalClosure ||
            (code > WebSocketStatus.internalServerError && code < 3000) ||
            code > 4999);
  }
}

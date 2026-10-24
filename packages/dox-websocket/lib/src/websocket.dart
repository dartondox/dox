import 'dart:async';

import 'package:dox_annotation/dox_annotation.dart';
import 'package:dox_websocket/src/adapters/websocket_adapter.dart';
import 'package:dox_websocket/src/websocket_event.dart';
import 'package:uuid/uuid.dart';

Uuid uuid = Uuid();

/// Decides if a client may join [room] with `joinRoom`.
/// [req] is the request that opened the websocket.
typedef JoinAuthorizer = FutureOr<bool> Function(IDoxRequest req, String room);

class WebsocketServer implements IDoxWebsocket {
  // Parameter for the singleton class
  final IDox? dox;

  // Static instance variable for the singleton
  static WebsocketServer? _instance;

  WebsocketServer._internal([this.dox]);

  factory WebsocketServer([IDox? d]) {
    if (_instance == null) {
      _instance = WebsocketServer._internal(d);
      _instance!._initialize();
    }
    return _instance!;
  }

  WebsocketAdapterInterface? _adaptor;

  /// decides if a client may join a room with `joinRoom`.
  /// when it is not set, every `joinRoom` is refused.
  JoinAuthorizer? authorizeJoin;

  /// origins (like `https://example.com`) that may open a websocket.
  /// a websocket from another origin gets 403.
  /// when null, any origin is allowed.
  List<String>? allowedOrigins;

  /// biggest message (in bytes) a client may send.
  /// a bigger message closes the connection with code 1009.
  int maxMessageSize = 1024 * 1024;

  void _initialize() {
    if (dox != null) {
      dox?.setWebsocket(this);
    }
  }

  @override
  WebsocketEventHandler create() {
    return WebsocketEventHandler();
  }

  void adapter(WebsocketAdapterInterface adaptor) {
    _adaptor = adaptor;
  }

  WebsocketAdapterInterface? getAdapter() {
    return _adaptor;
  }
}

import 'dart:async';
import 'dart:io';

import '../constants/engine_constants.dart';
import 'engine_packet.dart';
import 'transport.dart';

/// WebSocket transport. One frame holds one packet.
class WebsocketTransport extends Transport {
  WebsocketTransport(
    this._socket, {
    required this.maxHttpBufferSize,
    this._parser = const EngineParser(),
  }) {
    _subscription = _socket.listen(
      _onFrame,
      onDone: _onDone,
      onError: _onError,
      cancelOnError: true,
    );
  }

  final WebSocket _socket;
  final int maxHttpBufferSize;
  final EngineParser _parser;
  late final StreamSubscription<dynamic> _subscription;
  bool _closed = false;
  bool _closeCalled = false;

  @override
  String get name => transportWebsocket;

  @override
  bool get writable => !_closed;

  void _onFrame(dynamic frame) {
    if (_closed) return;
    int size = frame is String ? frame.length : (frame as List<int>).length;
    if (size > maxHttpBufferSize) {
      _closeWith(WebSocketStatus.messageTooBig, CloseReason.transportError);
      return;
    }
    EnginePacket packet;
    try {
      packet = _parser.decodeFrame(frame as Object);
    } on FormatException {
      _closeWith(
        WebSocketStatus.invalidFramePayloadData,
        CloseReason.parseError,
      );
      return;
    }
    listener?.onTransportPacket(this, packet);
  }

  void _onDone() => _notifyClose(CloseReason.transportClose);

  void _onError(Object error) => _notifyClose(CloseReason.transportError);

  void _closeWith(int code, String reason) {
    close(code);
    _notifyClose(reason);
  }

  void _notifyClose(String reason) {
    _closed = true;
    TransportListener? current = listener;
    listener = null;
    current?.onTransportClose(this, reason);
  }

  @override
  void send(List<EnginePacket> packets) {
    if (_closed) return;
    for (EnginePacket packet in packets) {
      _socket.add(_parser.encodeForWebsocket(packet));
    }
  }

  @override
  void close([int code = WebSocketStatus.normalClosure]) {
    if (_closeCalled) return;
    _closeCalled = true;
    _closed = true;
    unawaited(_subscription.cancel());
    unawaited(_socket.close(code).then(_ignore, onError: _ignore));
  }

  static void _ignore([Object? _, Object? _]) {}
}

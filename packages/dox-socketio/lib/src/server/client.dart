import 'dart:async';

import '../constants/engine_constants.dart';
import '../constants/socket_constants.dart';
import '../engine/engine_socket.dart';
import '../parser/socket_decoder.dart';
import '../parser/socket_encoder.dart';
import '../parser/socket_packet.dart';
import 'namespace.dart';
import 'socket.dart';
import 'socket_io_server.dart';

/// One Engine.IO connection. It can hold sockets of many namespaces.
class Client implements EngineSocketListener {
  Client(
    this.server,
    this.conn, {
    SocketEncoder encoder = const SocketEncoder(),
  }) : _encoder = encoder {
    conn.listener = this;
    _connectTimer = Timer(server.options.connectTimeout, _onConnectTimeout);
  }

  final SocketIoServer server;

  /// The Engine.IO session.
  final EngineSocket conn;

  final SocketEncoder _encoder;
  final SocketDecoder _decoder = SocketDecoder();
  final Map<String, Socket> _sockets = <String, Socket>{};
  Timer? _connectTimer;

  /// True while the connection is open.
  bool get isOpen => conn.isOpen;

  /// Encodes and sends one packet.
  void sendPacket(SocketPacket packet) => writeEncoded(_encoder.encode(packet));

  /// Sends a packet that is already encoded.
  void writeEncoded(List<Object> parts) {
    if (!conn.isOpen) return;
    for (Object part in parts) {
      conn.send(part);
    }
  }

  /// Adds a socket that passed the middlewares.
  void addSocket(Socket socket) => _sockets[socket.nsp.name] = socket;

  /// Forgets a socket that left.
  void remove(Socket socket) {
    if (_sockets[socket.nsp.name] == socket) _sockets.remove(socket.nsp.name);
  }

  /// Disconnects all sockets and closes the connection.
  void disconnect() {
    for (Socket socket in List<Socket>.of(_sockets.values)) {
      socket.disconnect();
    }
    conn.close();
  }

  @override
  void onEngineMessage(Object data) {
    SocketPacket? packet;
    try {
      packet = _decoder.add(data);
    } on FormatException {
      conn.close(CloseReason.parseError);
      return;
    }
    if (packet != null) _onPacket(packet);
  }

  @override
  void onEngineClose(String reason) {
    _connectTimer?.cancel();
    for (Socket socket in List<Socket>.of(_sockets.values)) {
      socket.onClose(reason);
    }
    _sockets.clear();
  }

  void _onPacket(SocketPacket packet) {
    if (packet.type == SocketPacketType.connect) {
      unawaited(_connect(packet));
      return;
    }
    _sockets[packet.nsp]?.onPacket(packet);
  }

  Future<void> _connect(SocketPacket packet) async {
    _connectTimer?.cancel();
    _connectTimer = null;
    if (_sockets.containsKey(packet.nsp)) return;
    Namespace? nsp = server.namespaceFor(packet.nsp);
    if (nsp == null) {
      sendPacket(SocketPacket(
        type: SocketPacketType.connectError,
        nsp: packet.nsp,
        data: const <String, Object>{'message': invalidNamespaceMessage},
      ));
      return;
    }
    Object? auth = packet.data;
    await nsp.add(
      this,
      auth is Map ? auth.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  void _onConnectTimeout() {
    if (_sockets.isEmpty) conn.close();
  }
}

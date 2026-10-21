import 'dart:async';

import '../adapter/adapter.dart';
import '../constants/socket_constants.dart';
import '../parser/socket_packet.dart';
import '../utils/id_generator.dart';
import 'broadcast_operator.dart';
import 'client.dart';
import 'handler_runner.dart';
import 'handshake.dart';
import 'socket.dart';
import 'socket_io_exception.dart';

/// Handles a new socket.
typedef ConnectionHandler = FutureOr<void> Function(Socket socket);

/// Runs before a socket connects. Throw [SocketIoException] to refuse it.
typedef Middleware = FutureOr<void> Function(Socket socket);

/// A class-based namespace. Register it with `io.register(handler)`.
///
/// ```dart
/// class ChatNamespace extends NamespaceHandler {
///   @override
///   String get path => '/chat';
///
///   @override
///   void onConnection(Socket socket) => socket.on('message', onMessage);
///
///   void onMessage(SocketEvent event) => event.ack('ok');
/// }
/// ```
abstract class NamespaceHandler {
  /// Namespace name.
  String get path => defaultNamespace;

  /// Middlewares of this namespace, in order.
  List<Middleware> get middleware => const <Middleware>[];

  /// Called for each new socket.
  FutureOr<void> onConnection(Socket socket);
}

/// A namespace, like `/` or `/chat`. It holds its sockets and middlewares.
class Namespace {
  Namespace(
    this.name,
    this.adapter, {
    IdGenerator? ids,
    HandlerRunner runner = const HandlerRunner(),
  })  : _ids = ids ?? IdGenerator(),
        _runner = runner {
    adapter.init(this);
  }

  /// Namespace name.
  final String name;

  /// Adapter that keeps the rooms and does broadcasts.
  final Adapter adapter;

  /// Connected sockets on this server, by id.
  final Map<String, Socket> sockets = <String, Socket>{};

  final IdGenerator _ids;
  final HandlerRunner _runner;
  final List<Middleware> _middleware = <Middleware>[];
  final List<ConnectionHandler> _connectionHandlers = <ConnectionHandler>[];

  /// Adds a middleware. Middlewares run in the order they are added.
  void use(Middleware middleware) => _middleware.add(middleware);

  /// Listens for `connection` (or `connect`).
  void on(String event, ConnectionHandler handler) {
    if (event != connectionEvent && event != 'connect') {
      throw ArgumentError.value(event, 'event', 'only connection is allowed');
    }
    _connectionHandlers.add(handler);
  }

  /// Same as `on('connection', handler)`.
  void onConnection(ConnectionHandler handler) => on(connectionEvent, handler);

  /// Sends to sockets in [room].
  BroadcastOperator to(String room) =>
      BroadcastOperator(this, rooms: <String>{room});

  /// Sends to all sockets except the ones in [room].
  BroadcastOperator except(String room) =>
      BroadcastOperator(this, except: <String>{room});

  /// Sends only to sockets of this server.
  BroadcastOperator get local => BroadcastOperator(this, local: true);

  /// Sends [event] to all sockets of this namespace.
  Future<void> emit(String event, [Object? data]) =>
      BroadcastOperator(this).emit(event, data);

  /// Sends [event] with many arguments to all sockets of this namespace.
  Future<void> emitArgs(String event, List<Object?> args) =>
      BroadcastOperator(this).emitArgs(event, args);

  /// All sockets of this namespace on this server.
  List<Socket> fetchSockets() => BroadcastOperator(this).fetchSockets();

  /// Disconnects all sockets of this namespace on this server.
  void disconnectSockets([bool close = false]) =>
      BroadcastOperator(this).disconnectSockets(close);

  /// Runs the middlewares and connects a new socket for [client].
  Future<void> add(Client client, Map<String, dynamic> auth) async {
    Socket socket = Socket(
      id: _ids.next(),
      nsp: this,
      client: client,
      handshake: Handshake(client.conn.request, auth),
    );
    try {
      for (Middleware middleware in _middleware) {
        await middleware(socket);
      }
    } catch (error) {
      client.sendPacket(SocketPacket(
        type: SocketPacketType.connectError,
        nsp: name,
        data: error is SocketIoException
            ? error.toJson()
            : <String, Object>{'message': error.toString()},
      ));
      return;
    }
    if (!client.isOpen) return;
    sockets[socket.id] = socket;
    client.addSocket(socket);
    socket.onConnect();
    for (ConnectionHandler handler
        in List<ConnectionHandler>.of(_connectionHandlers)) {
      await _runner.run(handler, socket);
    }
  }

  /// Forgets a socket that left.
  void remove(Socket socket) => sockets.remove(socket.id);
}

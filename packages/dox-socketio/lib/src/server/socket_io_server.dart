import 'dart:async';
import 'dart:io';

import '../adapter/adapter.dart';
import '../adapter/in_memory_adapter.dart';
import '../constants/socket_constants.dart';
import '../engine/engine_server.dart';
import '../engine/engine_socket.dart';
import '../engine/http_responder.dart';
import '../engine/server_options.dart';
import '../utils/id_generator.dart';
import 'broadcast_operator.dart';
import 'client.dart';
import 'namespace.dart';

/// Socket.IO v4 server.
///
/// ```dart
/// SocketIoServer io = SocketIoServer();
/// io.on('connection', onConnection);
/// await io.listen(3000);
/// ```
class SocketIoServer implements EngineConnectionListener {
  SocketIoServer({
    this.options = const ServerOptions(),
    Adapter? adapter,
    IdGenerator? ids,
    HttpResponder responder = const HttpResponder(),
  })  : adapter = adapter ?? InMemoryAdapter(),
        _ids = ids ?? IdGenerator(),
        _responder = responder {
    engine = EngineServer(options: options, connectionListener: this);
    of(defaultNamespace);
  }

  final ServerOptions options;

  /// Adapter shared by all namespaces.
  final Adapter adapter;

  /// The Engine.IO server under this server.
  late final EngineServer engine;

  final IdGenerator _ids;
  final HttpResponder _responder;
  final Map<String, Namespace> _namespaces = <String, Namespace>{};
  HttpServer? _httpServer;

  /// The default namespace `/`.
  Namespace get sockets => of(defaultNamespace);

  /// Returns the namespace [name]. It is created on first use.
  Namespace of(String name) {
    String key = name.startsWith('/') ? name : '/$name';
    return _namespaces[key] ??= Namespace(key, adapter, ids: _ids);
  }

  /// Returns the namespace [name], or null when it does not exist.
  Namespace? namespaceFor(String name) => _namespaces[name];

  /// Adds a middleware to the default namespace.
  void use(Middleware middleware) => sockets.use(middleware);

  /// Listens for `connection` on the default namespace.
  void on(String event, ConnectionHandler handler) =>
      sockets.on(event, handler);

  /// Adds a class-based namespace.
  void register(NamespaceHandler handler) {
    Namespace nsp = of(handler.path);
    for (Middleware middleware in handler.middleware) {
      nsp.use(middleware);
    }
    nsp.onConnection(handler.onConnection);
  }

  /// Sends to sockets in [room] of the default namespace.
  BroadcastOperator to(String room) => sockets.to(room);

  /// Sends to sockets of the default namespace, except those in [room].
  BroadcastOperator except(String room) => sockets.except(room);

  /// Sends only to sockets of this server.
  BroadcastOperator get local => sockets.local;

  /// Sends [event] to all sockets of the default namespace.
  Future<void> emit(String event, [Object? data]) => sockets.emit(event, data);

  /// True when [request] is for this server (its path starts with
  /// [ServerOptions.path]).
  bool matches(HttpRequest request) {
    String path = request.uri.path;
    String base = options.path;
    return path.startsWith(base) ||
        (base.endsWith('/') && path == base.substring(0, base.length - 1));
  }

  /// Handles one HTTP request. Mount it on any `dart:io` server.
  Future<void> handle(HttpRequest request) async {
    try {
      await engine.handle(request);
    } catch (error) {
      stderr.writeln('dox_socketio: request error: $error');
      _responder.send(request.response, HttpStatus.internalServerError, '');
    }
  }

  /// Starts a `dart:io` server on [port]. Use port 0 for a free port.
  Future<HttpServer> listen(
    int port, {
    Object address = '127.0.0.1',
  }) async {
    HttpServer server = await HttpServer.bind(address, port);
    attach(server);
    return server;
  }

  /// Handles the Socket.IO requests of [server]. Other requests get 404.
  void attach(HttpServer server) {
    _httpServer = server;
    server.listen(_onHttpRequest);
  }

  void _onHttpRequest(HttpRequest request) {
    if (matches(request)) {
      unawaited(handle(request));
    } else {
      _responder.send(request.response, HttpStatus.notFound, 'Not Found');
    }
  }

  @override
  void onEngineConnection(EngineSocket socket) => Client(this, socket);

  /// Disconnects everyone and stops the server.
  Future<void> close() async {
    engine.close();
    await adapter.close();
    await _httpServer?.close(force: true);
    _httpServer = null;
  }
}

import 'dart:io';

import '../constants/engine_constants.dart';
import '../utils/id_generator.dart';
import 'engine_request.dart';
import 'engine_socket.dart';
import 'http_responder.dart';
import 'polling_transport.dart';
import 'server_options.dart';
import 'transport.dart';
import 'websocket_transport.dart';

/// Gets told about new Engine.IO sessions.
abstract class EngineConnectionListener {
  /// A new session is open.
  void onEngineConnection(EngineSocket socket);
}

/// Engine.IO v4 server. It turns HTTP requests into sessions.
class EngineServer implements EngineSessionStore {
  EngineServer({
    required this.options,
    required this.connectionListener,
    IdGenerator? ids,
    HttpResponder responder = const HttpResponder(),
  })  : _ids = ids ?? IdGenerator(),
        _responder = responder;

  final ServerOptions options;
  final EngineConnectionListener connectionListener;
  final IdGenerator _ids;
  final HttpResponder _responder;
  final Map<String, EngineSocket> _sessions = <String, EngineSocket>{};

  /// Number of open sessions.
  int get clientsCount => _sessions.length;

  /// Handles one HTTP request for the Engine.IO path.
  Future<void> handle(HttpRequest request) async {
    HttpResponse response = request.response;
    CorsOptions? cors = options.cors;
    if (cors != null) _applyCors(request, cors);
    if (request.method == 'OPTIONS') {
      if (cors == null) {
        _responder.error(response, EngineError.badRequest);
      } else {
        _responder.send(response, HttpStatus.noContent, '');
      }
      return;
    }

    Map<String, String> query = request.uri.queryParameters;
    if (query['EIO'] != engineProtocolVersion) {
      _responder.error(response, EngineError.unsupportedProtocolVersion);
      return;
    }
    String? transport = query['transport'];
    if (transport == null || !options.transports.contains(transport)) {
      _responder.error(response, EngineError.unknownTransport);
      return;
    }
    bool isWebsocket = transport == transportWebsocket;
    if (isWebsocket && !WebSocketTransformer.isUpgradeRequest(request)) {
      _responder.error(response, EngineError.badRequest);
      return;
    }

    String? sid = query['sid'];
    if (sid == null) {
      await _handshake(request, isWebsocket);
      return;
    }
    EngineSocket? session = _sessions[sid];
    if (session == null) {
      _responder.error(response, EngineError.unknownSid);
      return;
    }
    if (isWebsocket) {
      await _upgrade(request, session);
      return;
    }
    Transport current = session.transport;
    if (current is PollingTransport) {
      await current.handleRequest(request);
    } else {
      _responder.error(response, EngineError.badRequest);
    }
  }

  Future<void> _handshake(HttpRequest request, bool isWebsocket) async {
    if (request.method != 'GET') {
      _responder.error(request.response, EngineError.badHandshakeMethod);
      return;
    }
    EngineRequest info = EngineRequest.fromHttpRequest(request);
    Transport transport;
    if (isWebsocket) {
      WebSocket socket = await WebSocketTransformer.upgrade(request);
      transport = WebsocketTransport(
        socket,
        maxHttpBufferSize: options.maxHttpBufferSize,
      );
    } else {
      transport = PollingTransport(
        maxHttpBufferSize: options.maxHttpBufferSize,
      );
    }
    EngineSocket session = EngineSocket(
      id: _ids.next(),
      request: info,
      transport: transport,
      options: options,
      store: this,
    );
    _sessions[session.id] = session;
    session.open();
    connectionListener.onEngineConnection(session);
    if (transport is PollingTransport) await transport.handleRequest(request);
  }

  Future<void> _upgrade(HttpRequest request, EngineSocket session) async {
    if (!options.allowUpgrades ||
        session.upgrading ||
        session.transport is! PollingTransport) {
      _responder.error(request.response, EngineError.badRequest);
      return;
    }
    WebSocket socket = await WebSocketTransformer.upgrade(request);
    session.maybeUpgrade(WebsocketTransport(
      socket,
      maxHttpBufferSize: options.maxHttpBufferSize,
    ));
  }

  void _applyCors(HttpRequest request, CorsOptions cors) {
    String? origin = request.headers.value('origin');
    if (origin == null || !cors.allows(origin)) return;
    HttpHeaders headers = request.response.headers;
    bool anyOrigin = cors.origins.contains('*') && !cors.credentials;
    headers.set('Access-Control-Allow-Origin', anyOrigin ? '*' : origin);
    if (!anyOrigin) headers.add(HttpHeaders.varyHeader, 'Origin');
    if (cors.credentials) {
      headers.set('Access-Control-Allow-Credentials', 'true');
    }
    if (request.method != 'OPTIONS') return;
    headers.set('Access-Control-Allow-Methods', cors.methods.join(','));
    String? asked = request.headers.value('access-control-request-headers');
    String? allowed = cors.allowedHeaders?.join(',') ?? asked;
    if (allowed != null) headers.set('Access-Control-Allow-Headers', allowed);
    Duration? maxAge = cors.maxAge;
    if (maxAge != null) {
      headers.set('Access-Control-Max-Age', maxAge.inSeconds.toString());
    }
  }

  @override
  void removeSession(String id) => _sessions.remove(id);

  /// Closes all sessions.
  void close([String reason = CloseReason.serverShuttingDown]) {
    for (EngineSocket session in List<EngineSocket>.of(_sessions.values)) {
      session.close(reason);
    }
  }
}

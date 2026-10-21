import '../constants/engine_constants.dart';

/// CORS settings for the HTTP long-polling requests.
class CorsOptions {
  const CorsOptions({
    this.origins = const <String>['*'],
    this.credentials = false,
    this.methods = const <String>['GET', 'POST'],
    this.allowedHeaders,
    this.maxAge,
  });

  /// Allowed origins. `*` allows any origin.
  final List<String> origins;

  /// Send `Access-Control-Allow-Credentials: true`.
  final bool credentials;

  /// Allowed methods for preflight requests.
  final List<String> methods;

  /// Allowed request headers. When null, the requested headers are allowed.
  final List<String>? allowedHeaders;

  /// How long a browser may cache the preflight answer.
  final Duration? maxAge;

  /// True when [origin] may call the server.
  bool allows(String origin) {
    return origins.contains('*') || origins.contains(origin);
  }
}

/// Options of the Engine.IO and Socket.IO server.
class ServerOptions {
  const ServerOptions({
    this.path = defaultPath,
    this.pingInterval = defaultPingInterval,
    this.pingTimeout = defaultPingTimeout,
    this.upgradeTimeout = defaultUpgradeTimeout,
    this.connectTimeout = defaultConnectTimeout,
    this.maxHttpBufferSize = defaultMaxHttpBufferSize,
    this.transports = const <String>[transportPolling, transportWebsocket],
    this.allowUpgrades = true,
    this.cors,
  });

  /// URL path the server listens on. Must end with `/`.
  final String path;

  /// Time between two server pings.
  final Duration pingInterval;

  /// Time to wait for a pong before the session is closed.
  final Duration pingTimeout;

  /// Time a websocket upgrade may take.
  final Duration upgradeTimeout;

  /// Time a client has to join a namespace after the handshake.
  final Duration connectTimeout;

  /// Biggest message (in bytes) a client may send.
  final int maxHttpBufferSize;

  /// Allowed transports.
  final List<String> transports;

  /// Allow upgrades from polling to websocket.
  final bool allowUpgrades;

  /// CORS settings. When null, no CORS headers are sent.
  final CorsOptions? cors;
}

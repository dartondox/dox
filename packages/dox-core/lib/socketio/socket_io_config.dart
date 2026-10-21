import 'package:dox_socketio/dox_socketio.dart';

/// Socket.IO on the Dox HTTP port, at `/socket.io/`. Off by default.
///
/// ```
/// SocketIoConfig(
///   enabled: true,
///   namespaces: [ChatNamespace()],
///   adapter: RedisSocketAdapterFactory(), // needed with many isolates
/// );
/// ```
///
/// Many isolates: each isolate has its own Socket.IO server. Use the Redis
/// adapter so a broadcast reaches clients on every isolate. Clients must use
/// `transports: ['websocket']`. HTTP long-polling sends many requests,
/// and they can reach different isolates, so it needs `totalIsolate: 1`
/// (or sticky sessions in front of many servers).
class SocketIoConfig {
  /// Mount Socket.IO on the HTTP port.
  final bool enabled;

  /// Engine options (path, ping, cors, transports).
  final ServerOptions options;

  /// Namespaces to register, like `ChatNamespace()`.
  final List<NamespaceHandler> namespaces;

  /// Makes the adapter in each isolate. Null means in memory (one isolate).
  final SocketAdapterFactory? adapter;

  const SocketIoConfig({
    this.enabled = false,
    this.options = const ServerOptions(),
    this.namespaces = const <NamespaceHandler>[],
    this.adapter,
  });
}

/// Makes a Socket.IO [Adapter] inside each isolate. A Redis connection can
/// not be sent to another isolate, so it is made where it is used.
abstract class SocketAdapterFactory {
  const SocketAdapterFactory();

  /// A new adapter for this isolate.
  Adapter create();
}

/// Engine.IO protocol version this server speaks.
const String engineProtocolVersion = '4';

/// Character between packets in an HTTP long-polling payload.
const String pollingSeparator = '\x1e';

/// Prefix of a base64 binary packet in a polling payload.
const String pollingBinaryPrefix = 'b';

/// Data of the ping/pong packets used to probe a websocket upgrade.
const String probeData = 'probe';

/// Transport names.
const String transportPolling = 'polling';
const String transportWebsocket = 'websocket';

/// Default option values. They match the Node.js server.
const Duration defaultPingInterval = Duration(milliseconds: 25000);
const Duration defaultPingTimeout = Duration(milliseconds: 20000);
const Duration defaultUpgradeTimeout = Duration(milliseconds: 10000);
const Duration defaultConnectTimeout = Duration(milliseconds: 45000);
const int defaultMaxHttpBufferSize = 1000000;
const int defaultMaxAttachments = 10;
const String defaultPath = '/socket.io/';

/// How often a pending poll is released with a noop while upgrading.
const Duration upgradeCheckInterval = Duration(milliseconds: 100);

/// Engine.IO packet types. The index is the wire value.
enum EnginePacketType { open, close, ping, pong, message, upgrade, noop }

/// Engine.IO HTTP error codes and messages.
enum EngineError {
  unknownTransport(0, 'Transport unknown'),
  unknownSid(1, 'Session ID unknown'),
  badHandshakeMethod(2, 'Bad handshake method'),
  badRequest(3, 'Bad request'),
  forbidden(4, 'Forbidden'),
  unsupportedProtocolVersion(5, 'Unsupported protocol version');

  const EngineError(this.code, this.message);

  final int code;
  final String message;
}

/// Reasons given when an Engine.IO session closes.
class CloseReason {
  static const String transportClose = 'transport close';
  static const String transportError = 'transport error';
  static const String pingTimeout = 'ping timeout';
  static const String parseError = 'parse error';
  static const String forcedClose = 'forced close';
  static const String serverShuttingDown = 'server shutting down';
  static const String serverNamespaceDisconnect = 'server namespace disconnect';
  static const String clientNamespaceDisconnect = 'client namespace disconnect';
}

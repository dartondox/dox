import '../engine/engine_request.dart';

/// Details of the connection, like `socket.handshake` in Node.js.
class Handshake {
  Handshake(EngineRequest request, this.auth)
    : headers = request.headers,
      query = request.query,
      address = request.address,
      url = request.url,
      secure = request.secure,
      time = request.time;

  /// Request headers. Names are lower case.
  final Map<String, String> headers;

  /// Query parameters of the first request.
  final Map<String, String> query;

  /// The `auth` payload the client sent with CONNECT.
  final Map<String, dynamic> auth;

  /// Remote IP address.
  final String address;

  /// URL of the first request.
  final String url;

  /// True for HTTPS.
  final bool secure;

  /// When the connection was opened.
  final DateTime time;

  /// [time] in milliseconds since epoch.
  int get issued => time.millisecondsSinceEpoch;
}

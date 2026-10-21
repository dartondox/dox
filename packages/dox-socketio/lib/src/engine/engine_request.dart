import 'dart:io';

/// What the server knows about the HTTP request that opened a session.
class EngineRequest {
  EngineRequest({
    required this.headers,
    required this.query,
    required this.address,
    required this.url,
    required this.secure,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  /// Reads the useful parts of [request].
  factory EngineRequest.fromHttpRequest(HttpRequest request) {
    Map<String, String> headers = <String, String>{};
    request.headers.forEach((String name, List<String> values) {
      headers[name.toLowerCase()] = values.join(', ');
    });
    return EngineRequest(
      headers: headers,
      query: request.uri.queryParameters,
      address: request.connectionInfo?.remoteAddress.address ?? '',
      url: request.uri.toString(),
      secure: request.requestedUri.scheme == 'https',
    );
  }

  /// Request headers. Names are lower case.
  final Map<String, String> headers;

  /// Query parameters of the first request.
  final Map<String, String> query;

  /// Remote IP address.
  final String address;

  /// Request URL (path and query).
  final String url;

  /// True for HTTPS.
  final bool secure;

  /// When the session was opened.
  final DateTime time;
}

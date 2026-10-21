import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../constants/engine_constants.dart';

/// Writes small HTTP answers and ignores errors from closed connections.
class HttpResponder {
  const HttpResponder();

  /// Sends [body] with [status] and [contentType], then closes the response.
  void send(
    HttpResponse response,
    int status,
    String body, {
    String contentType = 'text/plain; charset=UTF-8',
  }) {
    try {
      response.statusCode = status;
      response.headers.set(HttpHeaders.contentTypeHeader, contentType);
      List<int> bytes = utf8.encode(body);
      response.contentLength = bytes.length;
      response.add(bytes);
      unawaited(response.close().then(_ignore, onError: _ignore));
    } catch (_) {
      // The client is gone. Nothing to do.
    }
  }

  /// Sends an Engine.IO error as JSON.
  void error(HttpResponse response, EngineError error) {
    send(
      response,
      error == EngineError.forbidden
          ? HttpStatus.forbidden
          : HttpStatus.badRequest,
      jsonEncode(<String, Object>{
        'code': error.code,
        'message': error.message,
      }),
      contentType: 'application/json',
    );
  }

  static void _ignore([Object? _, Object? _]) {}
}

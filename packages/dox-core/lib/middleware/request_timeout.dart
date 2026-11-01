import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// Answers `503 Service Unavailable` when the rest of the middleware
/// and the controller take longer than [duration].
///
/// ```
/// Route.get('report', <dynamic>[
///   RequestTimeout(Duration(seconds: 30)),
///   reportController.show,
/// ]);
/// Route.get('report', reportController.show).timeout(Duration(seconds: 30));
/// ```
///
/// For every route, add it to `globalMiddleware`. The error is a normal
/// `HttpStatusException(503)` with the code `request_timeout`, so the
/// `ExceptionHandler` renders it, and reports it like every 5xx.
///
/// Dart can not stop a running Future. The controller keeps running in
/// the background, and its late result is dropped. It can not write to
/// the answer any more.
class RequestTimeout implements IDoxNextMiddleware {
  const RequestTimeout(this.duration);

  /// the longest time the request may take
  final Duration duration;

  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    try {
      return await next().timeout(duration);
    } on TimeoutException {
      throw HttpStatusException(
        HttpStatus.serviceUnavailable,
        message: 'The request took too long',
        errorCode: 'request_timeout',
      );
    }
  }
}

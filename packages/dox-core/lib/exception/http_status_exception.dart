import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// An error answer with any status code, and optional headers.
/// ```
/// throw HttpStatusException(409, message: 'The email is taken');
/// throw HttpStatusException(503, headers: {'retry-after': '60'});
/// ```
/// See also [abort].
class HttpStatusException extends IHttpException {
  HttpStatusException(
    int code, {
    dynamic message,
    String? errorCode,
    this.headers = const <String, String>{},
  }) {
    super.code = code;
    super.errorCode = errorCode ?? _errorCodes[code] ?? 'http_error';
    super.message = message ?? _messages[code] ?? 'Error';
  }

  /// headers sent with the error answer, eg. `Allow` for 405
  final Map<String, String> headers;
}

/// Stop the request and answer with [code].
/// ```
/// if (post.userId != req.auth?.id()) abort(403);
/// abort(404, 'No post with this id');
/// ```
Never abort(
  int code, [
  dynamic message,
  Map<String, String> headers = const <String, String>{},
]) {
  throw HttpStatusException(code, message: message, headers: headers);
}

/// 403 Forbidden: the user is known, but may not do this.
class ForbiddenHttpException extends HttpStatusException {
  ForbiddenHttpException({super.message, super.errorCode})
    : super(HttpStatus.forbidden);
}

/// 405 Method Not Allowed. [allow] is sent in the `Allow` header.
/// Dox throws it when the path has routes, but not for this method.
class MethodNotAllowedHttpException extends HttpStatusException {
  MethodNotAllowedHttpException(this.allow, {super.message, super.errorCode})
    : super(
        HttpStatus.methodNotAllowed,
        headers: <String, String>{'allow': allow.join(', ')},
      );

  /// the methods the path has routes for, eg. `['GET', 'HEAD']`
  final List<String> allow;
}

const Map<int, String> _errorCodes = <int, String>{
  400: 'bad_request',
  401: 'unauthorized',
  402: 'payment_required',
  403: 'forbidden',
  404: 'not_found',
  405: 'method_not_allowed',
  409: 'conflict',
  410: 'gone',
  422: 'unprocessable_entity',
  429: 'too_many_requests',
  500: 'server_error',
  503: 'service_unavailable',
};

const Map<int, String> _messages = <int, String>{
  400: 'Bad Request',
  401: 'Unauthorized',
  402: 'Payment Required',
  403: 'Forbidden',
  404: 'Not Found',
  405: 'Method Not Allowed',
  409: 'Conflict',
  410: 'Gone',
  422: 'Unprocessable Entity',
  429: 'Too Many Requests',
  500: 'Server Error',
  503: 'Service Unavailable',
};

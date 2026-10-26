import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// Thrown when a client sends too many requests, eg. by [RateLimit].
/// Dox answers with 429 Too Many Requests.
class TooManyRequestsException extends IHttpException {
  TooManyRequestsException({
    dynamic message = 'Too Many Requests',
    String errorCode = 'too_many_requests',
    int code = HttpStatus.tooManyRequests,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

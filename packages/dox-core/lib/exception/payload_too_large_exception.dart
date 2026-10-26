import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// Thrown when a request body is bigger than the configured limit.
/// Dox answers with 413 Payload Too Large.
class PayloadTooLargeException extends IHttpException {
  PayloadTooLargeException({
    dynamic message = 'Payload Too Large',
    String errorCode = 'payload_too_large',
    int code = HttpStatus.requestEntityTooLarge,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

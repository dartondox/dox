import 'dart:io';

import 'package:dox_core/dox_core.dart';

class ValidationException extends IHttpException {
  ValidationException({
    dynamic message = const <String, dynamic>{},
    String errorCode = 'validation_failed',
    int code = HttpStatus.unprocessableEntity,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

import 'dart:io';

import 'package:dox_core/dox_core.dart';

class ValidationException extends HttpException {
  ValidationException({
    message = const {},
    errorCode = 'validation_failed',
    code = HttpStatus.unprocessableEntity,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

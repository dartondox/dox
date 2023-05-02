import 'dart:io';

import 'package:dox_core/dox_core.dart';

class ValidationException extends BaseHttpException {
  ValidationException({
    message = 'Validation failed',
    errorCode = 'validation_failed',
    code = HttpStatus.unprocessableEntity,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

import 'dart:io';

import 'package:dox_core/dox_core.dart';

class ValidationException extends BaseHttpException {
  @override
  final int code;

  @override
  final String errorCode;

  @override
  final String message;

  ValidationException({
    this.message = 'Validation failed',
    this.errorCode = 'validation_failed',
    this.code = HttpStatus.unprocessableEntity,
  });
}

import 'dart:io';

import 'package:dox_core/dox_core.dart';

class ValidationException extends IHttpException {
  ValidationException({
    dynamic message = const <String, dynamic>{},
    String errorCode = 'validation_failed',
    int code = HttpStatus.unprocessableEntity,
    this.issues = const <ValidationIssue>[],
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }

  /// Every issue of the failed check, with its path, rule `code`, message
  /// and params. [message] has only the first message of each path.
  /// An `ExceptionHandler` can use it to send another error shape, like
  /// `[{field, message, rule}]`. Empty when the error was made by hand.
  final List<ValidationIssue> issues;
}

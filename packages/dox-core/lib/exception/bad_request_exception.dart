import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// Thrown when the body can not be read, like JSON that is not valid.
/// Dox answers with 400 Bad Request.
class BadRequestException extends IHttpException {
  BadRequestException({
    String message = 'Bad Request',
    String errorCode = 'bad_request',
    int code = HttpStatus.badRequest,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

/// Thrown when a DTO reads a body of a type Dox can not read
/// (not JSON, not form data). Dox answers with 415.
class UnsupportedMediaTypeException extends IHttpException {
  UnsupportedMediaTypeException({
    String message = 'Unsupported Media Type',
    String errorCode = 'unsupported_media_type',
    int code = HttpStatus.unsupportedMediaType,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

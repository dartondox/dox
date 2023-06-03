import 'dart:io';

import 'package:dox_core/dox_core.dart';

class InternalErrorException extends HttpException {
  InternalErrorException({
    String message = 'Server Error',
    String errorCode = 'server_error',
    int code = HttpStatus.internalServerError,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

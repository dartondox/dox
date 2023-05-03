import 'dart:io';

import 'package:dox_core/dox_core.dart';

class InternalErrorException extends BaseHttpException {
  InternalErrorException({
    message = 'Server Error',
    errorCode = 'server_error',
    code = HttpStatus.internalServerError,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

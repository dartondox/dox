import 'dart:io';

import 'package:dox_core/dox_core.dart';

class UnAuthorizedException extends HttpException {
  UnAuthorizedException({
    String message = 'Failed to authorize',
    String errorCode = 'unauthorized',
    int code = HttpStatus.unauthorized,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

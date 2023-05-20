import 'dart:io';

import 'package:dox_core/dox_core.dart';

class UnAuthorizedException extends HttpException {
  UnAuthorizedException({
    message = 'Failed to authorize',
    errorCode = 'unauthorized',
    code = HttpStatus.unauthorized,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

import 'dart:io';

import 'package:dox_core/dox_core.dart';

class NotFoundHttpException extends HttpException {
  NotFoundHttpException({
    message = 'Not Found',
    errorCode = 'not_found',
    code = HttpStatus.notFound,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

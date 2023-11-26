import 'dart:io';

import 'package:dox_core/dox_core.dart';

class NotFoundHttpException extends IHttpException {
  NotFoundHttpException({
    String message = 'Not Found',
    String errorCode = 'not_found',
    int code = HttpStatus.notFound,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

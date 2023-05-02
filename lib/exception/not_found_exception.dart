import 'dart:io';

import 'package:dox_core/dox_core.dart';

class NotFoundHttpException extends BaseHttpException {
  @override
  final int code;

  @override
  final String errorCode;

  @override
  final String message;

  NotFoundHttpException({
    this.message = 'Not Found',
    this.errorCode = 'not_found',
    this.code = HttpStatus.notFound,
  });
}

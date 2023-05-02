import 'dart:io';

import 'package:dox_core/dox_core.dart';

class AuthorizationException extends BaseHttpException {
  @override
  final int code;

  @override
  final String errorCode;

  @override
  final String message;

  AuthorizationException({
    this.message = 'Failed to authorization',
    this.errorCode = 'unauthorized',
    this.code = HttpStatus.unauthorized,
  });
}

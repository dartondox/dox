import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// 403. Thrown when the user may not do this.
class ForbiddenException extends IHttpException {
  ForbiddenException({String message = 'Forbidden'}) {
    super.code = HttpStatus.forbidden;
    super.errorCode = 'forbidden';
    super.message = message;
  }
}

/// 409. Thrown when the row already exists or was changed by someone else.
class ConflictException extends IHttpException {
  ConflictException({String message = 'Conflict'}) {
    super.code = HttpStatus.conflict;
    super.errorCode = 'conflict';
    super.message = message;
  }
}

import 'dart:io';

import 'package:dox_core/dox_core.dart';

class QueryException extends BaseHttpException {
  @override
  final int code;

  @override
  final String errorCode;

  @override
  final String message;

  QueryException({
    this.message = 'Error in sql query',
    this.errorCode = 'sql_query_error',
    this.code = HttpStatus.internalServerError,
  });
}

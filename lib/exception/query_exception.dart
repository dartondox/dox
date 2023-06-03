import 'dart:io';

import 'package:dox_core/dox_core.dart';

class QueryException extends HttpException {
  QueryException({
    String message = 'Error in sql query',
    String errorCode = 'sql_query_error',
    int code = HttpStatus.internalServerError,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

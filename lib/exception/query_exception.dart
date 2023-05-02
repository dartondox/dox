import 'dart:io';

import 'package:dox_core/dox_core.dart';

class QueryException extends BaseHttpException {
  QueryException({
    message = 'Error in sql query',
    errorCode = 'sql_query_error',
    code = HttpStatus.internalServerError,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

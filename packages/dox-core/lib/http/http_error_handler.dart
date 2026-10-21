import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_validation/dox_validation.dart' as dv;

void httpErrorHandler(HttpRequest req, Object? error, StackTrace stackTrace) {
  /// `schema.parse()` in a controller: answer 422 like `req.validate()`
  if (error is dv.ValidationException) {
    error = ValidationException(message: error.errors);
  }
  if (error is Exception || error is Error) {
    Dox().config.errorHandler(error, stackTrace);
  }
  httpResponseHandler(error, req);
}

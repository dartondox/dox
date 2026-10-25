import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/utils/logger.dart';
import 'package:dox_validation/dox_validation.dart' as dv;

/// Every error of a request comes here. The `ExceptionHandler` of
/// `AppConfig` reports it and decides the response.
void httpErrorHandler(HttpRequest req, Object error, StackTrace stackTrace) {
  /// `schema.parse()` in a controller: answer 422 like `req.validate()`
  if (error is dv.ValidationException) {
    error = ValidationException(message: error.errors);
  }
  ExceptionHandler handler = Dox().config.exceptionHandler;
  dynamic payload = error;
  try {
    if (error is! IHttpException) handler.report(error, stackTrace);
    payload = handler.render(error, req);
  } catch (handlerError, handlerStack) {
    /// a broken handler must not leave the client waiting.
    /// send the default answer for the first error.
    Logger.danger('ExceptionHandler failed: $handlerError\n$handlerStack');
  }
  httpResponseHandler(payload, req);
}

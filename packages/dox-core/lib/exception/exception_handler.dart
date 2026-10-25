import 'dart:io';

import 'package:dox_core/utils/logger.dart';

/// The one place that turns a thrown error into a response.
///
/// Extend it and set it in `AppConfig(exceptionHandler: ...)`.
/// ```
/// class AppExceptionHandler extends ExceptionHandler {
///   @override
///   void report(Object error, StackTrace stackTrace) {
///     sentry.captureException(error, stackTrace: stackTrace);
///   }
///
///   @override
///   dynamic render(Object error, HttpRequest req) {
///     if (error is PaymentRequiredException) {
///       return response({'message': 'Please pay'}).statusCode(402);
///     }
///     return super.render(error, req);
///   }
/// }
/// ```
class ExceptionHandler {
  const ExceptionHandler();

  /// Log the error. Dox calls it for every error that is not an
  /// `IHttpException` (those are normal answers like 404 or 422), and for
  /// errors outside a request, like a future that nobody awaited.
  /// The default prints the error and the stack with the logger.
  void report(Object error, StackTrace stackTrace) {
    Logger.warn(error);
    Logger.danger(stackTrace.toString());
  }

  /// What to send for [error]. Return anything a controller can return:
  /// a `DoxResponse`, a map, a string. Return [error] itself (the
  /// default) for the default answer:
  ///
  /// - an `IHttpException` gets its own status and
  ///   `{"code": ..., "message": ...}`. Validation errors get 422.
  /// - any other error gets 500 with
  ///   `{"code": "server_error", "message": "Server Error"}`. When
  ///   `APP_ENV` is `development` or `local`, the error text is sent
  ///   instead.
  ///
  /// The `responseHandler` of `AppConfig` still runs after it.
  dynamic render(Object error, HttpRequest req) {
    return error;
  }
}

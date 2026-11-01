import 'dart:io';

import 'package:dox_core/dox_core.dart';

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

  /// The `X-Request-Id` of the request whose error is being reported
  /// (see `RequestId`). It is set only while [report] runs for an error
  /// of a request. Read it at the start of [report], before any `await`.
  /// ```
  /// sentry.captureException(error, hint: ExceptionHandler.requestId);
  /// ```
  static String? get requestId => _requestId;
  static String? _requestId;

  /// Log the error. Dox calls it for every error, except an
  /// `IHttpException` with a 4xx code (those are normal answers like 404
  /// or 422). It is also called for errors outside a request, like a
  /// future that nobody awaited.
  /// The default prints the error and the stack with the logger, and the
  /// [requestId] when there is one.
  void report(Object error, StackTrace stackTrace) {
    String? id = _requestId;
    Logger.warn(id == null ? error : '[request $id] $error');
    Logger.danger(stackTrace.toString());
  }

  /// [report] for an error of [req], with [requestId] set while it runs.
  void reportFor(HttpRequest req, Object error, StackTrace stackTrace) {
    _requestId = req.response.headers.value(RequestId.header);
    try {
      report(error, stackTrace);
    } finally {
      _requestId = null;
    }
  }

  /// What to send for [error]. Return anything a controller can return:
  /// a `DoxResponse`, a map, a string. Return [error] itself (the
  /// default) for the default answer:
  ///
  /// - an `IHttpException` gets its own status and
  ///   `{"code": ..., "message": ...}`. Validation errors get 422.
  /// - a validation error on a request with a session
  ///   (`SessionMiddleware`) that does not want JSON (a form post, an
  ///   Inertia request) flashes the `errors` and the old input, and
  ///   redirects back. See `Session.flashErrors`.
  /// - any other error gets 500 with
  ///   `{"code": "server_error", "message": "Server Error"}`. When
  ///   `APP_ENV` is `development` or `local`, the error text is sent
  ///   instead.
  ///
  /// The `responseHandler` of `AppConfig` still runs after it.
  dynamic render(Object error, HttpRequest req) {
    if (error is ValidationException) {
      DoxRequest? doxReq = SessionMiddleware.requestOf(req);
      if (doxReq != null && !doxReq.expectsJson()) {
        doxReq.session.flashErrors(error.message, input: doxReq.all());
        return back(doxReq);
      }
    }
    return error;
  }
}

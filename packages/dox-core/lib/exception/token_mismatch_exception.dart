import 'package:dox_core/dox_core.dart';

/// Thrown by [CsrfMiddleware] when the CSRF token of a request is
/// missing or wrong. Dox answers with 419.
class TokenMismatchException extends IHttpException {
  TokenMismatchException({
    dynamic message = 'CSRF token mismatch',
    String errorCode = 'csrf_token_mismatch',
    int code = 419,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}

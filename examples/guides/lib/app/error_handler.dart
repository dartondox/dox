import 'dart:convert';

import 'package:dox_core/dox_core.dart';

/// Dox calls [report] for every unexpected error (a `500`, or an error
/// outside a request). It does not run for `IHttpException` errors
/// like `404` or `422`, because those are expected.
/// One JSON line per error. Send it to Sentry or Datadog from here.
class AppExceptionHandler extends ExceptionHandler {
  const AppExceptionHandler();

  @override
  void report(Object error, StackTrace stackTrace) {
    print(
      jsonEncode(<String, String>{
        'level': 'ERROR',
        'message': error.toString(),
        'stack': stackTrace.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }
}

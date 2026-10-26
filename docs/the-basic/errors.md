---
icon: lucide/triangle-alert
---

# Error handling

Every error that a route throws goes to one place: the exception handler.
It does two things:

- `report(error, stackTrace)` logs the error.
- `render(error, req)` decides what the client gets.

## The default answer

You do not need to set anything. With the default handler:

| Error | Status | Body |
| --- | --- | --- |
| an `IHttpException`, like `NotFoundHttpException` | its `code` | `{"code": "not_found", "message": "Not Found"}` |
| a `ValidationException` (bad input) | `422` | the field errors, like `{"name": "The name is required"}` |
| a `ValidationException` on a request with a [session](session.md#redirect-back-with-errors) that does not want JSON, like a form post | `302` | a redirect back. The errors and the old input are in the session. |
| a URL with no route | `404` | `{"code": "not_found", "message": "GET /x not found"}` |
| any other error | `500` | `{"code": "server_error", "message": "Server Error"}` |

For a `500`, the error text is sent only when `APP_ENV` is `development` or `local`.
In production the client never sees it, because it can hold SQL, file paths or hosts.

`report` is called for every error that is not an `IHttpException`.
An `IHttpException` is a normal answer (like `404`), so it is not logged.
The default `report` prints the error and the stack with the logger.

See [HTTP exceptions](../reference/http-exceptions.md) for the built-in exception classes.

## Your own handler

Extend `ExceptionHandler`. Override one method or both.

```dart title="lib/app/exception_handler.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';

class PaymentRequiredException implements Exception {}

class AppExceptionHandler extends ExceptionHandler {
  const AppExceptionHandler();

  @override
  void report(Object error, StackTrace stackTrace) {
    // send it to your error tracker
    print('ERROR $error\n$stackTrace');
  }

  @override
  dynamic render(Object error, HttpRequest req) {
    if (error is PaymentRequiredException) {
      return response(<String, String>{'message': 'Please pay'})
          .statusCode(402);
    }
    // everything else: the default answer
    return super.render(error, req);
  }
}
```

Set it in `AppConfig`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  exceptionHandler: const AppExceptionHandler(),
  // ...
);
```

## What render can return

`render` returns anything a controller can return: a `DoxResponse`, a map, a string.
Return the error itself (this is what `super.render` does) to get the default answer.

`req` is the raw `HttpRequest`. It is there even when the error came before Dox read the body.
Use it to read headers, like `req.headers.value('accept')`.

If `render` itself throws, Dox logs that error and sends the default answer.
The client always gets a response.

## Errors outside a request

Some errors do not belong to a request.
For example a future that nobody awaits, or an error in the `shutdown()` of a provider.
Dox passes them to `report` too. The server keeps running.

## The response handler

The `responseHandler` of `AppConfig` still runs after `render`.
It sees every response, also error responses.
Use `render` to change errors, and `responseHandler` to change all responses (for example, to add a header).

See [Custom errors](../guides/custom-errors.md) for a full example with your own exception classes.

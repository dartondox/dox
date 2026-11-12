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

`report` is called for every error, except an `IHttpException` with a `4xx` code.
A `4xx` exception is a normal answer (like `404`), so it is not logged.
A `5xx` exception, like `InternalErrorException`, is reported.
The default `report` prints the error and the stack with the logger.

See [HTTP exceptions](../reference/http-exceptions.md) for the built-in exception classes.

## An HTML error page

By default an error is sent as JSON. In `development` or `local`, a `500` is plain text with the error text. A browser that opens a bad URL sees JSON or text, not a page.
To send an HTML page to browsers, turn on `htmlErrors`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  htmlErrors: true,
  // ...
);
```

The page has the status and its title, like `404 Not Found`.
It loads no files from outside.

- Only a request that does not want JSON gets the page. A request wants JSON (`DoxRequest.expectsJson()`) when it has an `Accept` header with json, a JSON body, or `X-Requested-With: XMLHttpRequest`. An Inertia request does not want JSON, so it gets the page.
- Only when `APP_ENV` is `development` or `local`, the page also shows the error text and the stack trace.
- JSON clients still get JSON.
- A validation error does not change. It keeps its `422` JSON or its redirect.
- An answer from your own `ExceptionHandler.render` does not change.

To make your own page, set `errorPage`. It gets the status, the error, the stack trace and a `debug` flag.
`debug` is `true` when `APP_ENV` is `development` or `local`.
Escape every value you put in the page.

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  htmlErrors: true,
  errorPage: (int status, Object error, StackTrace stack, bool debug) =>
      '<h1>Sorry, error $status</h1>',
  // ...
);
```

`defaultErrorPage` is the default. You can call it from your own function, for example for the statuses you do not handle.

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

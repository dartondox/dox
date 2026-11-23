---
icon: lucide/triangle-alert
---

# Error handling

Every error that a route throws goes to one exception handler, which logs it and sends an answer to the client.

The handler has two methods:

- `report(error, stackTrace)` logs the error.
- `render(error, req)` decides what the client gets.

You do not need to set anything up. The default handler already gives good answers. You only write your own handler when you want to change them.

## The default answer

This is what the client gets with the default handler:

| Error | Status | Body |
| --- | --- | --- |
| an `IHttpException`, like `NotFoundHttpException` | its `code` | `{"code": "not_found", "message": "Not Found"}` |
| a `ValidationException` (bad input) | `422` | the field errors, like `{"name": "The name is required"}` |
| a `ValidationException` on a request with a [session](session.md#validation-errors-and-old-input) that does not want JSON, like a form post | `302` | a redirect back. The errors and the old input are in the session. |
| a URL with no route | `404` | `{"code": "not_found", "message": "GET /x not found"}` |
| any other error | `500` | `{"code": "server_error", "message": "Server Error"}` |

For a `500`, the error text is sent only when `APP_ENV` is `development` or `local`. In production the client never sees it, because it can hold SQL, file paths or hosts.

See [HTTP exceptions](../reference/http-exceptions.md) for the built-in exception classes.

### Which errors are logged

`report` is called for every error, except an `IHttpException` with a `4xx` code. A `4xx` exception (like `404`) is a normal answer, so it is not logged. A `5xx` exception, like `InternalErrorException`, is logged. The default `report` prints the error and the stack with the logger.

## An HTML error page

By default an error is sent as JSON, so a browser that opens a bad URL sees JSON, not a page. In `development` or `local`, a `500` is plain text with the error text.

If you want browsers to get an HTML page, turn on `htmlErrors`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  htmlErrors: true,
  // ...
);
```

The page shows the status and its title, like `404 Not Found`. It loads no files from outside. When `APP_ENV` is `development` or `local`, the page also shows the error text and the stack trace.

Only a request that does not want JSON gets the page. A JSON client, a validation error and an answer from your own `render` stay the same.

### Your own error page

To make your own page, set `errorPage`. It gets the status, the error, the stack trace and a `debug` flag. `debug` is `true` when `APP_ENV` is `development` or `local`. Escape every value you put in the page.

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  htmlErrors: true,
  errorPage: (int status, Object error, StackTrace stack, bool debug) =>
      '<h1>Sorry, error $status</h1>',
  // ...
);
```

The default page is `defaultErrorPage`. You can call it from your own function, for example for the statuses you do not handle.

## Your own handler

Sometimes you want to send errors to an error tracker, or give your own exception a special answer. For this, extend `ExceptionHandler` and override one method or both:

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

Then set it in `AppConfig`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  exceptionHandler: const AppExceptionHandler(),
  // ...
);
```

### What render can return

`render` can return anything a controller can return: a `DoxResponse`, a map or a string. If you return the error itself, the client gets the default answer. This is what `super.render` does.

`req` is the raw `HttpRequest`. It is there even when the error came before Dox read the body. Use it to read headers, like `req.headers.value('accept')`.

See [Custom errors](../guides/custom-errors.md) for a full example with your own exception classes.

## Errors of one route

Some routes answer in their own format, like gRPC. A JSON error makes no sense to their clients. `.renderErrorsWith` gives the errors of one route to your own function. It covers the errors of the middleware too, and a body that fails to read (for example a broken multipart body):

```dart
DoxResponse? rpcError(Object error, DoxRequest req) {
  return response(<String, String>{'error': 'failed'}).statusCode(500);
}

Route.post('/rpc', (RpcController c) => c.call).renderErrorsWith(rpcError);
```

The error is still reported. Return `null` to get the normal answer from your `ExceptionHandler`.

Dox sends routes to every isolate. So the function must be a top-level or static function, or one that captures nothing. A request with a `_method` override (`MethodOverride`) is not covered for a body error, because its route is not known before the body is read.

## Show error text only in development

Your code may send an error answer itself. Then use `showErrors()` to decide if the client may see the error text. It is `true` when `APP_ENV` is `development` or `local`, the same rule as the Dox error answers:

```dart
String message = showErrors() ? '$error' : 'Server Error';
```

## Details

- A request wants JSON (`DoxRequest.expectsJson()`) when it has an `Accept` header with json, a JSON body, or `X-Requested-With: XMLHttpRequest`. An Inertia request does not want JSON, so it gets the HTML page.
- If `render` itself throws, Dox logs that error and sends the default answer. The client always gets a response.
- Errors outside a request, like a future that nobody awaits or an error in the `shutdown()` of a provider, also go to `report`. The server keeps running.
- The `responseHandler` of `AppConfig` still runs after `render`, so it sees error responses too. Use `render` to change errors, and `responseHandler` to change all responses.

## See also

- [HTTP exceptions](../reference/http-exceptions.md): the exception classes and their status codes.
- [Custom errors](../guides/custom-errors.md): your own exceptions and one JSON shape, step by step.
- [Error index](../reference/errors.md): every message Dox prints or throws.

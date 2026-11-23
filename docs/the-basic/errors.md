---
icon: lucide/triangle-alert
---

# Error handling

Every error that a route throws goes to one exception handler, which logs it and sends an answer to the client.

The handler has two methods. `report(error, stackTrace)` logs the error, and `render(error, req)` decides what the client gets. The default handler works with no setup.

## The default answer

This is what the client gets with the default handler:

| Error | Status | Body |
| --- | --- | --- |
| an `IHttpException`, like `NotFoundHttpException` | its `code` | `{"code": "not_found", "message": "Not Found"}` |
| a `ValidationException` (bad input) | 422 | the field errors, like `{"name": "The name is required"}` |
| a `ValidationException` on a form post with a [session](session.md#validation-errors-and-old-input) | 302 | a redirect back, with the errors and the old input in the session |
| a URL with no route | 404 | `{"code": "not_found", "message": "GET /x not found"}` |
| any other error | 500 | `{"code": "server_error", "message": "Server Error"}` |

For a 500, the client gets the error text only when `APP_ENV` is development or local. See [HTTP exceptions](../reference/http-exceptions.md) for the exception classes.

`report` runs for every error, except an `IHttpException` with a 4xx code. It also runs for errors outside a request, like a future that nobody awaits.

## An HTML error page

Send browsers an HTML page in place of JSON. A JSON client and a validation error get the same answer as before:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  htmlErrors: true,
);
```

The page shows the status and its title, like "404 Not Found". In development or local, it also shows the error text and the stack trace.

### Your own error page

Set `errorPage`. `debug` is true when `APP_ENV` is development or local:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  htmlErrors: true,
  errorPage: (int status, Object error, StackTrace stack, bool debug) =>
      '<h1>Sorry, error $status</h1>',
);
```

!!! warning
    Escape every value you put in the page.

Call `defaultErrorPage` with the same arguments for the statuses you do not handle.

## Your own handler

Extend `ExceptionHandler`, for example to send errors to an error tracker. Override one method or both:

```dart title="lib/app/exception_handler.dart"
class PaymentRequiredException implements Exception {}

class AppExceptionHandler extends ExceptionHandler {
  const AppExceptionHandler();

  @override
  void report(Object error, StackTrace stackTrace) {
    print('ERROR $error\n$stackTrace'); // send it to your error tracker
  }

  @override
  dynamic render(Object error, HttpRequest req) {
    if (error is PaymentRequiredException) {
      return response(<String, String>{'message': 'Please pay'})
          .statusCode(402);
    }
    return super.render(error, req); // the default answer
  }
}
```

Then set it in `AppConfig`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  exceptionHandler: const AppExceptionHandler(),
);
```

`render` can return anything a controller can return. Return the error itself for the default answer. `req` is the raw `HttpRequest`, so read headers with `req.headers.value('accept')`. See [Custom errors](../guides/custom-errors.md).

### The request id in a report

Read the id from [`RequestId`](middleware.md#request-id) at the start of `report`, before any await:

```dart
sentry.captureException(error, hint: ExceptionHandler.requestId);
```

## Errors of one route

Send the errors of one route to your own function, for example for gRPC. It also gets the errors of the middleware and of the body:

```dart
DoxResponse? rpcError(Object error, DoxRequest req) {
  return response(<String, String>{'error': 'failed'}).statusCode(500);
}

Route.post('/rpc', (RpcController c) => c.call)
    .renderErrorsWith(rpcError);
```

Return null to get the answer of your `ExceptionHandler`. The error is still reported. The function must be a top-level or static function, because Dox sends routes to every isolate.

## Show error text only in development

Decide if the client can see the error text in an answer you send yourself. It is true when `APP_ENV` is development or local:

```dart
String message = showErrors() ? '$error' : 'Server Error';
```

## Next steps

- [HTTP exceptions](../reference/http-exceptions.md): the exception classes and their status codes.
- [Custom errors](../guides/custom-errors.md): your own exceptions and one JSON shape.
- [Error index](../reference/errors.md): every message Dox prints or throws.

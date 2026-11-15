---
icon: lucide/octagon-alert
---

# Custom errors

Give your app its own exception classes, send every error in one JSON shape, and log the unexpected ones.

A client is easier to write when every error has the same shape. You also want to know when something breaks on the server, without showing the details to the client.

## What you need

- A Dox app.

## How Dox handles an error

First, see what Dox does when a controller or a middleware throws:

| Error | Status | What Dox does |
| --- | --- | --- |
| an `IHttpException`, like `NotFoundHttpException` | its `code` | sends `{"code": ..., "message": ...}`. Does **not** call `report` |
| a validation error (bad DTO input) | `422` | sends the field errors: `{"field": "message"}`. Does not call `report` |
| any other `Exception` or `Error` | `500` | sends `{"code":"server_error","message":"Server Error"}`. When `APP_ENV` is `development` or `local`, it sends the error text. Calls `report` |

`report` is a method of the [exception handler](../the-basic/errors.md). Every response goes through the `responseHandler` of `AppConfig` last, so this guide sets the error shape there.

## 1. Write your own exceptions

For a quick error, use `abort(403)` or `abort(409, 'The email is taken')`. See [HTTP exceptions](../reference/http-exceptions.md#any-status-abort-and-httpstatusexception).

If you throw the same error in many places, write a class for it. Extend `IHttpException`, and set `code` (the HTTP status), `errorCode` (a short text for the client) and `message`:

```dart title="lib/app/exceptions/app_exception.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// 409. Thrown when the row already exists or was changed by someone else.
class ConflictException extends IHttpException {
  ConflictException({String message = 'Conflict'}) {
    super.code = HttpStatus.conflict;
    super.errorCode = 'conflict';
    super.message = message;
  }
}
```

Throw them anywhere in a controller, a middleware or a service:

```dart title="lib/app/http/controllers/user.controller.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/exceptions/app_exception.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class UserController {
  /// GET /api/users/{id}
  Future<User> show(int id) async {
    User? user = await User().find(id);
    if (user == null) {
      throw NotFoundHttpException(message: 'User $id not found');
    }
    return user;
  }

  /// DELETE /api/users/{id}
  Future<Map<String, bool>> destroy(int id) async {
    if (id == 1) {
      throw ForbiddenHttpException(message: 'The first user can not be deleted');
    }
    User user = await show(id);

    /// 0 rows: the user was deleted after show() found it
    if (await user.delete() == 0) {
      throw NotFoundHttpException(message: 'User $id not found');
    }
    return <String, bool>{'deleted': true};
  }
}
```

## 2. One JSON shape for every error

The response handler sees every response before it is sent. For an error, the content is the exception object, so you can turn it into your shape here:

```dart title="lib/app/http/response_handler.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// Gives every error the same JSON shape:
/// `{"error": {"code": "not_found", "message": "..."}}`.
/// A validation error (422) also has `"errors": {field: message}`.
class ResponseHandler extends ResponseHandlerInterface {
  @override
  DoxResponse handle(DoxResponse res) {
    dynamic content = res.getContent();

    if (content is ValidationException) {
      return res.statusCode(content.code).content(<String, dynamic>{
        'error': <String, dynamic>{
          'code': content.errorCode,
          'message': 'The input is not valid',
        },
        'errors': content.message,
      });
    }

    if (content is IHttpException) {
      return res.statusCode(content.code).content(<String, dynamic>{
        'error': <String, dynamic>{
          'code': content.errorCode,
          'message': content.message.toString(),
        },
      });
    }

    // any other exception: hide the details from the client
    if (content is Exception || content is Error) {
      return res.statusCode(HttpStatus.internalServerError).content(
        <String, dynamic>{
          'error': <String, String>{
            'code': 'server_error',
            'message': 'Something went wrong',
          },
        },
      );
    }

    return res;
  }
}
```

The last `if` gives a `500` your shape too, in every environment. Without it, the client gets the default body, which in `development` or `local` is the error text. That text can show a SQL query or a file path.

## 3. Log unexpected errors

You want to know about unexpected errors, so log them. The `report` method of the exception handler runs for every `500`, and for errors outside a request, like a future nobody awaited or a timer:

```dart title="lib/app/error_handler.dart"
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
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'error',
        'message': error.toString(),
        'error': <String, String>{'stack': stackTrace.toString()},
      }),
    );
  }
}
```

## 4. Register both

Add both handlers to `AppConfig`:

```dart title="lib/config/app.dart"
import 'package:my_app/app/error_handler.dart';
import 'package:my_app/app/http/response_handler.dart';

AppConfig appConfig = AppConfig(
  responseHandler: ResponseHandler(),
  exceptionHandler: const AppExceptionHandler(),
  // ...
);
```

## Check it

Add a route that throws, only for this check:

```dart
Route.get('/boom', (DoxRequest req) => throw StateError('boom'));
```

| Request | Status | Body |
| --- | --- | --- |
| `GET /api/users/999` | `404` | `{"error":{"code":"not_found","message":"User 999 not found"}}` |
| `GET /api/users/abc` | `404` | `{"error":{"code":"not_found","message":"Not Found"}}` |
| `DELETE /api/users/1` | `403` | `{"error":{"code":"forbidden","message":"The first user can not be deleted"}}` |
| `POST /api/auth/register` with `{}` | `422` | `{"error":{"code":"validation_failed","message":"The input is not valid"},"errors":{"name":"The name is required", ...}}` |
| `GET /api/boom` | `500` | `{"error":{"code":"server_error","message":"Something went wrong"}}` |

After `GET /api/boom`, the server prints one line:

```json
{"timestamp":"2026-10-22T14:01:12.000Z","status":"error","message":"Bad state: boom","error":{"stack":"#0  ApiRouter.register.<anonymous closure> (package:my_app/routes/api.dart:41:44) ..."},"source":"error"}
```

Remove the `/boom` route when you are done.

!!! note "A URL with no route"
    A URL that matches no route is a `NotFoundHttpException`. It goes through the response handler too, so it gets the same JSON shape:
    `{"error":{"code":"not_found","message":"GET /nothing not found"}}`.

## See also

- [Error handling](../the-basic/errors.md) for `report` and `render`
- [Response: errors](../the-basic/response.md#errors) for the built-in exceptions
- [Response: change every response](../the-basic/response.md#change-every-response)
- [Validation: the error response](../the-basic/validation.md#the-error-response)
- [Isolate: when an isolate crashes](../digging-deeper/isolate.md#when-an-isolate-crashes)

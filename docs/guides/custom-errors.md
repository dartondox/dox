# Custom errors

Give your app its own exception classes, send every error in one JSON shape, and log the unexpected ones.

## What you need

- A Dox app.

## How Dox handles an error

When a controller or a middleware throws:

| Error | Status | What Dox does |
| --- | --- | --- |
| an `IHttpException`, like `NotFoundHttpException` | its `code` | sends its `message`. Does **not** call `errorHandler` |
| a validation error (bad DTO input) | `422` | sends the field errors. Does not call `errorHandler` |
| any other `Exception` or `Error` | `500` | sends `error.toString()`. Calls `errorHandler` |

The response goes through the `responseHandler` of `AppConfig` last. That is where you set the shape.

## 1. Write your own exceptions

Extend `IHttpException`. Set `code` (the HTTP status), `errorCode` (a short text for the client) and `message`.

```dart title="lib/app/exceptions/app_exception.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// 403. Thrown when the user may not do this.
class ForbiddenException extends IHttpException {
  ForbiddenException({String message = 'Forbidden'}) {
    super.code = HttpStatus.forbidden;
    super.errorCode = 'forbidden';
    super.message = message;
  }
}

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
      throw ForbiddenException(message: 'The first user can not be deleted');
    }
    User user = await show(id);
    await user.delete();
    return <String, bool>{'deleted': true};
  }
}

UserController userController = UserController();
```

## 2. One JSON shape for every error

The response handler sees every response before it is sent. For an error, the content is the exception object.
Turn it into your shape here.

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

The last `if` matters. Without it, a `500` sends `error.toString()` to the client. That can show a SQL query or a file path.

## 3. Log unexpected errors

`errorHandler` runs for every `500`, and for errors outside a request (a future nobody awaited, a timer).
Write one JSON line. A log collector reads it, or you send it to Sentry here.

```dart title="lib/app/error_handler.dart"
import 'dart:convert';

/// Dox calls this for every unexpected error (a `500`, or an error
/// outside a request). It does not run for `IHttpException` errors
/// like `404` or `422`, because those are expected.
/// One JSON line per error. Send it to Sentry or Datadog from here.
void reportError(Object? error, StackTrace stackTrace) {
  print(
    jsonEncode(<String, String>{
      'level': 'ERROR',
      'message': error.toString(),
      'stack': stackTrace.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    }),
  );
}
```

## 4. Register both

```dart title="lib/config/app.dart"
import 'package:my_app/app/error_handler.dart';
import 'package:my_app/app/http/response_handler.dart';

AppConfig appConfig = AppConfig(
  responseHandler: ResponseHandler(),
  errorHandler: reportError,
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
{"level":"ERROR","message":"Bad state: boom","stack":"#0  ApiRouter.register.<anonymous closure> (package:my_app/routes/api.dart:40:44) ...","timestamp":"2026-10-22T14:01:12.000Z"}
```

Remove the `/boom` route when you are done.

!!! note "A URL with no route"
    A URL that matches no route answers `404` with the text `GET /nothing not found`.
    Dox answers this before the response handler runs, so it does not get the JSON shape.
    To change it, add a catch-all route at the end of your last router:
    `Route.get('/{path*}', (DoxRequest req) => throw NotFoundHttpException());`
    Do the same for `Route.post` and the other methods you use.

## See also

- [Response: errors](../the-basic/response.md#errors) for the built-in exceptions
- [Response: change every response](../the-basic/response.md#change-every-response)
- [Validation: the error response](../the-basic/validation.md#the-error-response)
- [Isolate: when an isolate crashes](../digging-deeper/isolate.md#when-an-isolate-crashes)

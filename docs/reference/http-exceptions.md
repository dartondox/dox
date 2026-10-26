---
icon: lucide/circle-x
---

# HTTP exceptions

An exception that extends `IHttpException` turns into an HTTP error answer.

You can `throw` it or `return` it from a middleware or a controller.

`IHttpException` is in `packages/dox-annotation/lib/src/core_annotation.dart`:

```dart
abstract class IHttpException {
  int code = 500;
  String errorCode = 'server_error';
  dynamic message = 'Server Error';

  dynamic toResponse() {
    if (message is Map) {
      return message;
    }
    return <String, dynamic>{'code': errorCode, 'message': message.toString()};
  }
}
```

## The classes

Every class takes the named parameters `message`, `errorCode` and `code`. The table shows the defaults.
`message` is a `String` or a `Map`, like `NotFoundHttpException(message: {'error': 'not_found'})`.

| Class | Package | Status `code` | `errorCode` | Default `message` | Dox throws it when |
| --- | --- | --- | --- | --- | --- |
| `BadRequestException` | `dox_core` | `400` | `bad_request` | `Bad Request` | the body can not be read, like JSON that is not valid |
| `UnAuthorizedException` | `dox_auth` | `401` | `unauthorized` | `Authentication failed` | `AuthMiddleware` finds no valid token |
| `NotFoundHttpException` | `dox_core` | `404` | `not_found` | `Not Found` | no route fits the path, a typed path param does not fit (`{id}` is not an `int`), or a route model binding finds no row |
| `PayloadTooLargeException` | `dox_core` | `413` | `payload_too_large` | `Payload Too Large` | the body is bigger than `maxBodySize` or `maxMultipartSize` |
| `UnsupportedMediaTypeException` | `dox_core` | `415` | `unsupported_media_type` | `Unsupported Media Type` | a DTO reads a body that is not JSON and not form data |
| `TokenMismatchException` | `dox_core` | `419` | `csrf_token_mismatch` | `CSRF token mismatch` | `CsrfMiddleware` finds no CSRF token, or a wrong one |
| `ValidationException` | `dox_core` | `422` | `validation_failed` | `{}` (a `Map`) | a DTO or `req.validate()` finds bad input |
| `TooManyRequestsException` | `dox_core` | `429` | `too_many_requests` | `Too Many Requests` | a `RateLimit` middleware sees too many requests |
| `InternalErrorException` | `dox_core` | `500` | `server_error` | `Server Error` | never by itself; for your own use |
| `QueryException` | `dox_core` | `500` | `sql_query_error` | `Error in sql query` | never by itself; for your own use |

Source files: `packages/dox-core/lib/exception/*.dart` and `packages/dox-auth/lib/src/auth_exception.dart`.

## What the client gets

`responseDataHandler` in `packages/dox-core/lib/http/http_response_handler.dart` sends the answer:

1. The status is set to `code`.
2. The body is `toResponse()`.
3. The body is sent as JSON with `Content-Type: application/json`.

A text message gives a JSON body with the `errorCode` and the `message`:

```dart
throw NotFoundHttpException(message: 'Blog not found');
```

```
HTTP/1.1 404 Not Found
content-type: application/json

{"code":"not_found","message":"Blog not found"}
```

A `Map` message is sent as it is, with no `code` key, and with the status of the exception:

```dart
throw NotFoundHttpException(message: <String, String>{'error': 'not_found'});
// 404 {"error":"not_found"}
```

`ValidationException` always has a map, one entry per field:

```
HTTP/1.1 422 Unprocessable Entity
content-type: application/json

{"email":"The email is not a valid email","name":"The name is required"}
```

A request for a path that has no route answers like a `NotFoundHttpException` with the message `<METHOD> <path> not found`: `{"code":"not_found","message":"GET /nothing not found"}`. Your `responseHandler` gets it too, so you can change its shape.

To send your own JSON shape, make your own exception class (see below) and override `toResponse()`.

Other errors: any `Exception` or `Error` that is not an `IHttpException` gets `500` with `{"code": "server_error", "message": "Server Error"}`. When `APP_ENV` is `development` or `local`, the body is `error.toString()` as text instead. It is also passed to the `report` method of the [exception handler](../the-basic/errors.md). An `IHttpException` is not reported.

A `ValidationException` on a request with a session (`SessionMiddleware`) that does not want JSON, like a form post, is not sent as JSON. Dox saves the errors and the old input in the session and redirects back.

A `ValidationException` from `dox_validation` (thrown by `schema.parse()` in a controller) is turned into the `422` `ValidationException` of `dox_core` with the same errors.

## Make your own

Extend `IHttpException` and set the three fields in the constructor:

```dart
import 'dart:io';

import 'package:dox_core/dox_core.dart';

class ForbiddenException extends IHttpException {
  ForbiddenException({
    dynamic message = 'Forbidden',
    String errorCode = 'forbidden',
    int code = HttpStatus.forbidden,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}
```

Override `toResponse()` to give every error of your app the same JSON shape.

More examples are on the [Response](../the-basic/response.md#errors) page.

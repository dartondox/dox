---
icon: lucide/circle-x
---

# HTTP exceptions

An HTTP exception stops a request and sends an error answer with the right status code, like `404` or `403`.

Each HTTP exception extends `IHttpException`, with three fields: the status `code`, a short `errorCode` and a `message`. Throw it, or return it from a middleware or a controller.

## Throwing an exception

Throw one of the classes below when a request cannot continue:

```dart
throw NotFoundHttpException(message: 'Blog not found');
```

The client gets a JSON body with the error code and the message:

```
HTTP/1.1 404 Not Found
content-type: application/json

{"code":"not_found","message":"Blog not found"}
```

## The classes

Most classes take the named parameters `message`, `errorCode` and `code`. The table shows the defaults.

| Class | Package | `code` | `errorCode` | Default `message` | Dox throws it when |
| --- | --- | --- | --- | --- | --- |
| `BadRequestException` | `dox_core` | `400` | `bad_request` | `Bad Request` | the body can not be read, like JSON that is not valid |
| `UnAuthorizedException` | `dox_auth` | `401` | `unauthorized` | `Authentication failed` | `AuthMiddleware` finds no valid token |
| `ForbiddenHttpException` | `dox_core` | `403` | `forbidden` | `Forbidden` | never; it is for your own use |
| `NotFoundHttpException` | `dox_core` | `404` | `not_found` | `Not Found` | no route fits (message `<METHOD> <path> not found`), a typed path param does not fit (`{id}` is not an `int`), or route model binding finds no row |
| `MethodNotAllowedHttpException` | `dox_core` | `405` | `method_not_allowed` | `Method Not Allowed` | the path has routes, but not for this method. The `Allow` header lists the methods, like `Allow: GET, POST, HEAD`. |
| `PayloadTooLargeException` | `dox_core` | `413` | `payload_too_large` | `Payload Too Large` | the body is bigger than `maxBodySize` or `maxMultipartSize` |
| `UnsupportedMediaTypeException` | `dox_core` | `415` | `unsupported_media_type` | `Unsupported Media Type` | a DTO reads a body that is not JSON and not form data |
| `TokenMismatchException` | `dox_core` | `419` | `csrf_token_mismatch` | `CSRF token mismatch` | `CsrfMiddleware` finds no CSRF token, or a wrong one |
| `ValidationException` | `dox_core` | `422` | `validation_failed` | `{}` (a `Map`) | a DTO, `req.validate()` or `schema.parse()` of `dox_validation` finds bad input |
| `TooManyRequestsException` | `dox_core` | `429` | `too_many_requests` | `Too Many Requests` | a `RateLimit` middleware sees too many requests |
| `InternalErrorException` | `dox_core` | `500` | `server_error` | `Server Error` | never; it is for your own use |
| `QueryException` | `dox_core` | `500` | `sql_query_error` | `Error in sql query` | never; it is for your own use |

## Any status: `abort` and `HttpStatusException`

For a status with no class, use `abort(code)`:

```dart
if (post.userId != req.auth?.id()) abort(403);
```

You can also pass a message:

```dart
abort(404, 'No post with this id');
```

`abort` throws an `HttpStatusException`. Throw it yourself to send headers too:

```dart
throw HttpStatusException(503,
    headers: <String, String>{'retry-after': '60'});
```

Common codes get a default `errorCode` and `message`, like `forbidden` and `Forbidden` for `403`:

```
HTTP/1.1 403 Forbidden
content-type: application/json

{"code":"forbidden","message":"Forbidden"}
```

Other codes get `http_error` and `Error`.

## What the client gets

The status is the code of the exception, and the body is JSON. A text message gives `{"code": "<errorCode>", "message": "<message>"}`. For your own JSON shape, give a map as the message:

```dart
throw NotFoundHttpException(
    message: <String, String>{'error': 'not_found'});
// 404 {"error":"not_found"}
```

A `ValidationException` always has a map, with one entry per field:

```
HTTP/1.1 422 Unprocessable Entity
content-type: application/json

{"email":"The email is not a valid email","name":"The name is required"}
```

A form post with a session gets a redirect back, with the errors and the old input in the session. See [Session](../the-basic/session.md#validation-errors-and-old-input).

### Other errors

Any other error gives 500 with `{"code": "server_error", "message": "Server Error"}`. When `APP_ENV` is development or local, the body is the error text.

These errors go to the `report` method of the [exception handler](../the-basic/errors.md). An HTTP exception with a 5xx code also goes there.

## Making your own exception

Extend `IHttpException` and set the three fields in the constructor:

```dart
import 'dart:io';

import 'package:dox_core/dox_core.dart';

class PaymentRequiredException extends IHttpException {
  PaymentRequiredException({
    dynamic message = 'Please pay',
    String errorCode = 'payment_required',
    int code = HttpStatus.paymentRequired,
  }) {
    super.code = code;
    super.errorCode = errorCode;
    super.message = message;
  }
}
```

To give each error the same JSON shape, override `toResponse()`. It returns the body.

## Next steps

- [Error handling](../the-basic/errors.md): report and render errors.
- [Response](../the-basic/response.md#errors): more error examples.
- [Error index](errors.md): each message that Dox shows or throws.

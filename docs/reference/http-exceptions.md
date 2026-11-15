---
icon: lucide/circle-x
---

# HTTP exceptions

An HTTP exception stops a request and sends an error answer with the right status code, like `404` or `403`.

Every HTTP exception extends `IHttpException`. It has three fields: the status `code`, a short `errorCode` like `not_found`, and a `message`. You can `throw` it, or `return` it from a middleware or a controller.

## Throwing an exception

Throw one of the classes below when a request can not go on. For example, when a post does not exist:

```dart
throw NotFoundHttpException(message: 'Blog not found');
```

The client gets a JSON body with the `errorCode` and the `message`:

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
| `NotFoundHttpException` | `dox_core` | `404` | `not_found` | `Not Found` | no route fits, a typed path param does not fit (`{id}` is not an `int`), or route model binding finds no row |
| `MethodNotAllowedHttpException` | `dox_core` | `405` | `method_not_allowed` | `Method Not Allowed` | the path has routes, but not for this method. The `Allow` header lists the methods. |
| `PayloadTooLargeException` | `dox_core` | `413` | `payload_too_large` | `Payload Too Large` | the body is bigger than `maxBodySize` or `maxMultipartSize` |
| `UnsupportedMediaTypeException` | `dox_core` | `415` | `unsupported_media_type` | `Unsupported Media Type` | a DTO reads a body that is not JSON and not form data |
| `TokenMismatchException` | `dox_core` | `419` | `csrf_token_mismatch` | `CSRF token mismatch` | `CsrfMiddleware` finds no CSRF token, or a wrong one |
| `ValidationException` | `dox_core` | `422` | `validation_failed` | `{}` (a `Map`) | a DTO or `req.validate()` finds bad input |
| `TooManyRequestsException` | `dox_core` | `429` | `too_many_requests` | `Too Many Requests` | a `RateLimit` middleware sees too many requests |
| `InternalErrorException` | `dox_core` | `500` | `server_error` | `Server Error` | never; it is for your own use |
| `QueryException` | `dox_core` | `500` | `sql_query_error` | `Error in sql query` | never; it is for your own use |

## Any status: `abort` and `HttpStatusException`

Sometimes you need a status that has no class. Use `abort(code)`. It stops the request and answers with that status:

```dart
if (post.userId != req.auth?.id()) abort(403);
```

You can also pass a message:

```dart
abort(404, 'No post with this id');
```

`abort` throws an `HttpStatusException`. Throw it yourself when you want to send headers too:

```dart
throw HttpStatusException(503, headers: {'retry-after': '60'});
```

Common codes get a default `errorCode` and `message`, like `forbidden` and `Forbidden` for `403`:

```
HTTP/1.1 403 Forbidden
content-type: application/json

{"code":"forbidden","message":"Forbidden"}
```

Other codes get `http_error` and `Error`.

## What the client gets

The status is the `code` of the exception. The body is sent as JSON with `Content-Type: application/json`.

A text message gives `{"code": "<errorCode>", "message": "<message>"}`, as shown above.

If you want your own JSON shape for one error, pass a `Map` as the message. It is sent as it is, with no `code` key:

```dart
throw NotFoundHttpException(message: <String, String>{'error': 'not_found'});
// 404 {"error":"not_found"}
```

A `ValidationException` always has a map, with one entry per field:

```
HTTP/1.1 422 Unprocessable Entity
content-type: application/json

{"email":"The email is not a valid email","name":"The name is required"}
```

A form post with a session (`SessionMiddleware`) does not get this JSON. Dox flashes the errors and the old input to the session and redirects back. See [Session](../the-basic/session.md#validation-errors-and-old-input).

### Other errors

Any other `Exception` or `Error` gives `500` with `{"code": "server_error", "message": "Server Error"}`. When `APP_ENV` is `development` or `local`, the body is the error text instead, so you can see what went wrong.

These errors go to the `report` method of the [exception handler](../the-basic/errors.md). An HTTP exception with a `5xx` code is reported too. One with a `4xx` code is not.

## Making your own exception

If you need an error that Dox does not have, extend `IHttpException` and set the three fields in the constructor:

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

To give every error of your app the same JSON shape, override `toResponse()`. It returns the body.

More examples are on the [Response](../the-basic/response.md#errors) page.

## Details

- A path with no route answers `404` with the message `<METHOD> <path> not found`, like `{"code":"not_found","message":"GET /nothing not found"}`.
- When the path has routes for other methods, the answer is `405` with an `Allow` header, like `Allow: GET, POST, HEAD`. Your `responseHandler` sees both, so you can change their shape.
- A `ValidationException` from `dox_validation` (from `schema.parse()` in a controller) becomes the `422` `ValidationException` of `dox_core`, with the same errors.

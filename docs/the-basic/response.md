# Response

This page shows what a controller can return, and how to set the status, headers and cookies.

## Return a value

Return the value from your controller. Dox turns it into the response.

| You return | The client gets |
| --- | --- |
| a `String` | the text |
| a `Map` or a `List` | JSON |
| a model, a list of models, a [serializer](../database/model/serializer.md) | JSON (from `toJson()`) |
| a `DateTime` | the ISO 8601 text |
| an `IHttpException`, like `NotFoundHttpException()` | its status code and its message (text, or JSON for a `Map`) |
| a `File` (from `dart:io`) | the file, streamed |
| a `Stream<List<int>>` | the bytes, streamed |
| `StreamFile`, `DownloadableFile` from `Storage()` | the file, streamed |
| `response(...)` | full control: status, headers, cookies |

```dart
// text
String ping(DoxRequest req) {
  return 'pong';
}

// JSON
Map<String, String> hello(DoxRequest req) {
  return <String, String>{'message': 'hello world!'};
}

// a model
Future<Blog?> show(int id) async {
  return Blog().find(id);
}

// a list of models
Future<List<Blog>> index(DoxRequest req) async {
  return Blog().all();
}

// an error
Future<Blog> showOrFail(int id) async {
  Blog? blog = await Blog().find(id);
  if (blog == null) {
    throw NotFoundHttpException(); // 404 Not Found
  }
  return blog;
}
```

## Errors

Throw or return an exception to answer with an error.

| Exception | Status |
| --- | --- |
| `BadRequestException()` | `400` |
| `NotFoundHttpException()` | `404` |
| `PayloadTooLargeException()` | `413` |
| `UnsupportedMediaTypeException()` | `415` |
| `ValidationException()` | `422` |
| `InternalErrorException()` | `500` |

Each one takes `message:`, `errorCode:` and `code:`:

```dart
throw NotFoundHttpException(message: 'Blog not found');
```

The client gets `404` with `{"code":"not_found","message":"Blog not found"}`.
`code` is the `errorCode`. A `Map` message is sent as it is.

For another status, extend `IHttpException`:

```dart
import 'dart:io';

import 'package:dox_core/dox_core.dart';

class ForbiddenException extends IHttpException {
  ForbiddenException({String message = 'Forbidden'}) {
    super.code = HttpStatus.forbidden;
    super.errorCode = 'forbidden';
    super.message = message;
  }
}
```

Any other error gets `500`. It is also passed to the `errorHandler` in `AppConfig`.

## Files and big responses

Return a `File` or a `Stream<List<int>>`. Dox sends it in chunks. It does not load it all into memory.

- A `File` sets `Content-Type` (from the file name), `Content-Length` and `Accept-Ranges`.
- It answers `Range: bytes=...` with `206 Partial Content`. Video players can seek, and downloads can resume.
- `Storage().stream()` and `Storage().download()` on the local disk also stream the file.

```dart
import 'dart:io';

// a file from disk
Route.get('/video', (DoxRequest req) => File('storage/video.mp4'));

// a download from Storage
Future<DownloadableFile> download(DoxRequest req) async {
  // sends Content-Disposition, so the browser saves the file
  return Storage().download('report.pdf');
}

// a stream from Storage
Future<StreamFile> show(DoxRequest req) async {
  return Storage().stream('photo.jpg');
}
```

See [File Storage](../digging-deeper/file-storage.md).

## The `response()` helper

Use `response(content)` when you need to set the status, headers or cookies.
All methods return the response, so you can chain them.

```dart
import 'dart:io';

import 'package:dox_core/dox_core.dart';

DoxResponse store(DoxRequest req) {
  return response(<String, String>{'status': 'created'})
      .statusCode(201)
      .header('X-Request-Id', 'abc')
      .contentType(ContentType.json);
}
```

| Method | Does |
| --- | --- |
| `statusCode(201)` | sets the status code. Default `200`. |
| `header('X-Key', 'value')` | adds one header |
| `withHeaders({...})` | **replaces** all headers set before |
| `contentType(ContentType.html)` | sets `Content-Type` (`ContentType` is from `dart:io`) |
| `cache(Duration(minutes: 5))` | sets `Cache-Control: max-age=300` |
| `cookie(DoxCookie(...))` | sets a cookie |
| `content(value)` | changes the body |
| `stream(byteStream)` | sends a `Stream<List<int>>` as the body |

## Cookie

```dart
// set a cookie
DoxCookie cookie = DoxCookie('theme', 'dark');
return response('ok').cookie(cookie);

// set a cookie with options
DoxCookie token = DoxCookie(
  'token',
  'value',
  maxAge: Duration(days: 7), // sent as Max-Age in seconds. default 1 hour
  httpOnly: true, // default true: page scripts can not read it
  secure: true,   // default: Secure only when the request came over https
  path: '/',
);
return response('ok').cookie(token);

// delete a cookie
return response('ok').cookie(DoxCookie('token', ''), setExpire: true);

// read a cookie
String? value = req.cookie('token');
```

!!! info "Encrypt and decrypt"
    By default, Dox encrypts the cookie value with `APP_KEY`, and decrypts it when you read it.
    To turn this off, use `DoxCookie(key, value, encrypt: false)` to set it,
    and `req.cookie(key, decrypt: false)` to read it.

## Change every response

To change every response in one place (for example, to add a header), set a `responseHandler` in `AppConfig`.

```dart title="lib/app/http/handler.dart"
import 'package:dox_core/dox_core.dart';

class ResponseHandler extends ResponseHandlerInterface {
  @override
  DoxResponse handle(DoxResponse res) {
    return res.header('X-Powered-By', 'Dox');
  }
}
```

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  responseHandler: ResponseHandler(),
  // ...
);
```

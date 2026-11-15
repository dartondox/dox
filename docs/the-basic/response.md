---
icon: lucide/arrow-up-from-line
---

# Response

A controller returns a value, and Dox turns it into the response for the client.

Most of the time you just return a string, a map or a model. When you need to set the status, headers or cookies, use the `response()` helper.

## Return a value

Return the value from your controller. Dox sends a `String` as text, and a `Map` or a model as JSON:

```dart
// JSON
Map<String, String> hello(DoxRequest req) {
  return <String, String>{'message': 'hello world!'};
}

// a model
Future<Blog?> show(int id) async {
  return Blog().find(id);
}
```

This is what the client gets for each type:

| You return | The client gets |
| --- | --- |
| a `String` | the text |
| a `Map` or a `List` | JSON |
| a model, a list of models, a [serializer](serializer.md) | JSON (from `toJson()`) |
| a `DateTime` | the ISO 8601 text |
| an `IHttpException`, like `NotFoundHttpException()` | its status code and JSON: `{"code": ..., "message": ...}`, or a `Map` message as it is |
| a `File` (from `dart:io`) | the file, streamed |
| a `Stream<List<int>>` | the bytes, streamed |
| `StreamFile`, `DownloadableFile` (also from `Storage()` of `dox_storage`) | the file, streamed |
| `response(...)` | full control: status, headers, cookies |

## Errors

To answer with an error, throw or return an exception:

```dart
throw NotFoundHttpException(message: 'Blog not found');
```

The client gets `404` with `{"code":"not_found","message":"Blog not found"}`. Each exception takes `message:`, `errorCode:` and `code:`. `code` in the JSON is the `errorCode`. A `Map` message is sent as it is.

Dox has these exceptions:

| Exception | Status |
| --- | --- |
| `BadRequestException()` | `400` |
| `NotFoundHttpException()` | `404` |
| `PayloadTooLargeException()` | `413` |
| `UnsupportedMediaTypeException()` | `415` |
| `TokenMismatchException()` | `419` |
| `ValidationException()` | `422` |
| `TooManyRequestsException()` | `429` |
| `InternalErrorException()` | `500` |

If you need another status, extend `IHttpException`:

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

Any other error gets `500`. It is also passed to the [exception handler](errors.md).

## Files and big responses

Return a `File` or a `Stream<List<int>>` to send a file. Dox sends it in chunks, so it does not load it all into memory:

```dart
import 'dart:io';

// a file from disk
Route.get('/video', (DoxRequest req) => File('storage/video.mp4'));
```

A `File` gets the right `Content-Type`, `Content-Length` and `Accept-Ranges`. It also answers `Range` requests with `206 Partial Content`, so video players can seek and downloads can resume.

### Files from storage

If you use [File Storage](../digging-deeper/file-storage.md), return `Storage().download()` to make the browser save the file. It sends `Content-Disposition`:

```dart
import 'package:dox_storage/dox_storage.dart';

// a download from Storage
Future<DownloadableFile> download(DoxRequest req) async {
  // sends Content-Disposition, so the browser saves the file
  return Storage().download('report.pdf');
}
```

To show the file in the browser instead, return `Storage().stream()`:

```dart
// a stream from Storage
Future<StreamFile> show(DoxRequest req) async {
  return Storage().stream('photo.jpg');
}
```

## The `response()` helper

Use `response(content)` when you need to set the status, headers or cookies. All methods return the response, so you can chain them:

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

### Setting the status

`statusCode` sets the status code. The default is `200`:

```dart
response(data).statusCode(201);
```

### Setting headers

`header` sets one header. If a middleware already put the same header on the response, the old value stays and this one is added. Pass `replace: true` to replace it:

```dart
response(data).header('X-Key', 'value');

response(data).header('X-Key', 'value', replace: true);
```

`withHeaders` adds many headers. A key replaces the header with the same name, in any case. Other headers stay:

```dart
response(data).withHeaders(<String, String>{'X-One': '1', 'X-Two': '2'});
```

`contentType` sets `Content-Type`. `ContentType` is from `dart:io`:

```dart
response(html).contentType(ContentType.html);
```

### Caching

`cache` sets `Cache-Control`. For example, `Duration(minutes: 5)` sends `Cache-Control: max-age=300`:

```dart
response(data).cache(Duration(minutes: 5));
```

### Changing the body

`content` changes the body, and `stream` sends a `Stream<List<int>>` as the body:

```dart
response('').content(value);

response('').stream(byteStream);
```

## Redirect

Use `redirect` to send the browser to another page. The status is `302`, unless you pass another one:

```dart
// 302 to a path
return redirect('/login');

// another status
return redirect('/posts', status: 301);
```

`back` sends the browser back to the page the request came from (the `Referer` header). When there is no `Referer`, or it points to another host, it goes to `/`. This is useful after a form post:

```dart
return back(req);
```

See [Session](session.md#flash-data) for flash messages and errors with a redirect.

## Cookie

To set a cookie, make a `DoxCookie` and add it with `cookie`:

```dart
DoxCookie cookie = DoxCookie('theme', 'dark');
return response('ok').cookie(cookie);
```

You can set the cookie options too:

```dart
DoxCookie token = DoxCookie(
  'token',
  'value',
  maxAge: Duration(days: 7), // sent as Max-Age in seconds. default 1 hour
  httpOnly: true, // default true: page scripts can not read it
  secure: true,   // default: Secure only when the request came over https
  path: '/',
  sameSite: SameSite.lax, // from dart:io. default: none sent
);
return response('ok').cookie(token);
```

To delete a cookie, pass `setExpire: true`:

```dart
return response('ok').cookie(DoxCookie('token', ''), setExpire: true);
```

Dox encrypts the cookie value with `APP_KEY`, and decrypts it when you read it. If the browser or another app must read the value, turn this off with `DoxCookie(key, value, encrypt: false)`. Then read it with `req.cookie(key, decrypt: false)`.

To read a cookie, see [Request: cookies](request.md#cookies).

## Change every response

Sometimes you want to change every response in one place, for example to add a header. Set a `responseHandler` in `AppConfig` for this:

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

## Details

- Some flags change this page: `htmlStrings` sends a string as `text/html`, `replaceHeaders` makes `header()` replace, and `cookieDefaults` sends `Path=/` and `SameSite=Lax` when you set no `path` or `sameSite`. See [Core flags](../reference/app-config.md#core-flags).
- `Storage().stream()` and `Storage().download()` on the local disk also stream the file.

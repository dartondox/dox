---
icon: lucide/arrow-up-from-line
---

# Response

A controller returns a value, and Dox turns it into the response for the client.

## Return a value

Return the value from your controller. Dox sends a string as text, and a map or a model as JSON:

```dart
Map<String, String> hello(DoxRequest req) {
  return <String, String>{'message': 'hello world!'};
}

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
| an `IHttpException`, like `NotFoundHttpException()` | its status code and JSON: `{"code": ..., "message": ...}` |
| a `File` (from `dart:io`) | the file, streamed |
| a `Stream<List<int>>` | the bytes, streamed |
| a `StreamFile` or a `DownloadableFile` | the file, streamed |
| `response(...)` | full control: status, headers, cookies |

The `htmlStrings` flag sends a string as HTML. See [Core flags](../reference/app-config.md#core-flags).

## Errors

Throw or return an exception to answer with an error:

```dart
throw NotFoundHttpException(message: 'Blog not found');
```

The client gets 404 with `{"code":"not_found","message":"Blog not found"}`. Each exception takes `message:` and `errorCode:`. A map message is sent as it is.

| Exception | Status |
| --- | --- |
| `BadRequestException()` | 400 |
| `ForbiddenHttpException()` | 403 |
| `NotFoundHttpException()` | 404 |
| `MethodNotAllowedHttpException(allow)` | 405 |
| `PayloadTooLargeException()` | 413 |
| `UnsupportedMediaTypeException()` | 415 |
| `TokenMismatchException()` | 419 |
| `ValidationException()` | 422 |
| `TooManyRequestsException()` | 429 |
| `InternalErrorException()` | 500 |
| `QueryException()` | 500 |

See [HTTP exceptions](../reference/http-exceptions.md) for all of them.

### Any status

Stop the request with any status, an optional message and headers:

```dart
if (post.userId != req.auth?.id()) abort(403);
throw HttpStatusException(503,
    headers: <String, String>{'retry-after': '60'});
```

### Your own exception

Extend `IHttpException`:

```dart
class PaymentRequiredException extends IHttpException {
  PaymentRequiredException({String message = 'Payment required'}) {
    super.code = HttpStatus.paymentRequired;
    super.errorCode = 'payment_required';
    super.message = message;
  }
}
```

Any other error gets 500, and goes to the [exception handler](errors.md).

## Files and big responses

Return a `File` or a `Stream<List<int>>` to send a file. Dox sends it in chunks:

```dart
Route.get('/video', (DoxRequest req) => File('storage/video.mp4'));
```

A file gets the right `Content-Type` and `Content-Length`. It also answers Range requests with 206, so video players can seek and downloads can resume.

### A stream with a type

Send a stream with its content type, or as a download with a file name:

```dart
return StreamFile(ContentType.parse('image/png'), bytes, length: size);
return DownloadableFile(ContentType.binary, bytes, 'report.pdf');
```

### Files from storage

Make the browser save a file from [File Storage](../digging-deeper/file-storage.md):

```dart
Future<DownloadableFile> download(DoxRequest req) async {
  return Storage().download('report.pdf');
}
```

Show the file in the browser:

```dart
Future<StreamFile> show(DoxRequest req) async {
  return Storage().stream('photo.jpg');
}
```

## The `response()` helper

Set the status, headers or cookies. All methods return the response, so you can chain them:

```dart
DoxResponse store(DoxRequest req) {
  return response(<String, String>{'status': 'created'})
      .statusCode(201)
      .header('X-Request-Id', 'abc')
      .contentType(ContentType.json);
}
```

### Setting the status

Set the status code. The default is 200:

```dart
response(data).statusCode(201);
```

### Setting headers

Set one header. If a middleware already set it, the new value is added. Pass `replace: true` to replace it:

```dart
response(data).header('X-Key', 'value');
response(data).header('X-Key', 'value', replace: true);
```

The `replaceHeaders` flag makes `header` replace by default. See [Core flags](../reference/app-config.md#core-flags).

Set many headers. Each key replaces the header with the same name:

```dart
response(data).withHeaders(<String, String>{'X-One': '1', 'X-Two': '2'});
```

Set the content type. `ContentType` is from `dart:io`:

```dart
response(html).contentType(ContentType.html);
```

### Caching

Set `Cache-Control`. `Duration(minutes: 5)` sends `max-age=300`:

```dart
response(data).cache(Duration(minutes: 5));
```

### Changing the body

Change the body, or send a byte stream as the body:

```dart
response('').content(value);
response('').stream(byteStream);
```

### Reading the response

Read the body, the status and the headers, for example in a [middleware](middleware.md#run-code-after-the-controller). A null status means 200:

```dart
res.getContent();
res.status;
res.headers;
```

## Redirect

Send the browser to another page. The status is 302 by default:

```dart
return redirect('/login');
return redirect('/posts', status: 301);
```

Send the browser back to the page of the Referer header, for example after a form post. With no Referer, or one of another host, it goes to the fallback:

```dart
return back(req);
return back(req, fallback: '/home');
```

See [Session](session.md#flash-data) for flash messages with a redirect.

## Cookie

Make a `DoxCookie` and add it to the response:

```dart
DoxCookie cookie = DoxCookie('theme', 'dark');
return response('ok').cookie(cookie);
```

Set the cookie options:

```dart
DoxCookie token = DoxCookie(
  'token',
  'value',
  maxAge: Duration(days: 7), // default 1 hour
  httpOnly: true, // default true: page scripts can not read it
  secure: true,   // default: only when the request came over https
  path: '/',
  sameSite: SameSite.lax, // from dart:io. default: none sent
);
return response('ok').cookie(token);
```

Delete a cookie:

```dart
return response('ok').cookie(DoxCookie('token', ''), setExpire: true);
```

Dox encrypts the cookie value with `APP_KEY`. If the browser or another app must read it, use `DoxCookie(key, value, encrypt: false)`, and read it with `req.cookie(key, decrypt: false)`. See [Request: cookies](request.md#cookies).

To decrypt a raw cookie value with no request, use `DoxCookie.decrypt(name, value)`.

## Send the response yourself

Write the raw response, for example a stream with trailers. See [Request: send the response yourself](request.md#send-the-response-yourself).

## Change every response

Change every response in one place, for example to add a header. Set a `responseHandler` in `AppConfig`:

```dart title="lib/app/http/handler.dart"
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
);
```

## Next steps

- [Serializer](serializer.md): set the JSON shape of a response.
- [Error handling](errors.md): report and render errors.
- [Request](request.md): read the input.

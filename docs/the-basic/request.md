# Request

This page shows how to read input, files, headers and cookies from a request.

## Typed input (recommended)

Ask for a [DTO](validation.md) in your controller. Dox reads the body (or the query for `GET`), checks it, and gives you a typed object.

```dart
Route.put('/users/{id}', controller.update);

class UserController {
  Future<User?> update( // (1)!
    int id, // (2)!
    UpdateUser input, // (3)!
  ) async {
    User? user = await User().find(id);
    user?.name = input.name;
    await user?.save();
    return user;
  }
}
```

1.  The return value is the response. Dox waits for a `Future`.
    A `String` is sent as text. A `Map` or a model is sent as JSON.
2.  A path param. It is `{id}` from the route. `/users/abc` answers `404`, because `abc` is not an `int`.
3.  A DTO. Dox reads the body, checks it, and builds the object before this method runs.

Bad input gets `422` before your method runs. See [Validation](validation.md).

## Raw input

Add a `DoxRequest` parameter to read the raw values. These values are **not** checked.

```dart
class ApiController {
  String sayHello(DoxRequest req) {
    String? name = req.input('name');
    return 'Hello $name';
  }
}
```

| Code | Gives |
| --- | --- |
| `req.input('name')` | one value from the query string or the body. The body wins when both have the key. |
| `req.all()` | all values from the query string and the body, as a `Map` |
| `req.only(<String>['name', 'email'])` | only these keys |
| `req.has('name')` | `true` when the key is there and not empty |
| `req.body` | the body only (JSON, form data) |
| `req.query` | the query string only |
| `req.add('key', value)`, `req.merge({...})` | add values, for example in a middleware |

## Route params

Ask for a path param as a typed parameter. `int id` gets `42` from `/users/42`.

```dart
Route.get('/hello/{name}', controller.sayHello);
Route.get('/users/{id}', controller.show);

class ApiController {
  String sayHello(String name) {
    return 'Hello $name';
  }

  Future<User?> show(int id) async {
    return User().find(id);
  }
}
```

The values are also in `req.param`, like `req.param['id']`.
See [Controller: parameters](controller.md#parameters).

## Form data (File)

An uploaded file is a `RequestFile`. The request must be `multipart/form-data`.
Put the file in a DTO, so Dox checks its type and size:

```dart
@Dto()
class UploadImage {
  @Image()
  @MaxSize('5MB')
  final RequestFile image;

  const UploadImage({required this.image});

  static const DtoSchema<UploadImage> schema = $UploadImageDto;
}

class ApiController {
  Future<Map<String, String>> uploadImage(UploadImage input) async {
    String uploadedPath = await input.image.store('images');
    return <String, String>{'filename': uploadedPath};
  }
}
```

Without a DTO, `req.input('image')` gives the `RequestFile`. It is not checked.

### `RequestFile`

```dart
RequestFile file = req.input('video');

file.filename;        // name from the client
file.filetype;        // content type, like video/mp4
file.extension;       // mp4
file.length;          // size in bytes
await file.size;      // size in KB
file.stream();        // read it in chunks
await file.store('videos');              // save to storage. returns the path
await file.moveTo('/data/videos/1.mp4'); // move it. returns the new File
await file.bytes;     // the whole file in memory. avoid for big files
```

!!! warning "Save the file before you return"
    A file up to 1 MB stays in memory. A bigger file is written to a temp file while it arrives.
    The temp file is **deleted when the response is sent**.
    So call `store`, `moveTo` or `stream` before your controller returns.

### Size limits

A body that is too big gets `413 Payload Too Large`. Dox checks `Content-Length` first.
It also counts the bytes while it reads the body.

```dart title="lib/config/app.dart"
AppConfig(
  maxBodySize: 10 * 1024 * 1024,        // JSON and urlencoded, default 10 MB
  maxMultipartSize: 100 * 1024 * 1024,  // form-data uploads, default 100 MB
);
```

Set the same limit in your proxy, like `client_max_body_size` in nginx.

## Headers

```dart
String? token = req.header('X-Token');
Map<String, dynamic> all = req.headers;

req.userAgent();  // User-Agent header
req.host();       // Host header
req.origin();     // Origin header, or null
req.referer();    // Referer header, or null
req.isJson();     // true for a JSON body
req.isFormData(); // true for multipart/form-data
req.locale;       // first language of Accept-Language, like 'th', or null
```

## Cookies

```dart
String? token = req.cookie('token');                 // decrypted value
String? raw = req.cookie('theme', decrypt: false);   // value as sent
```

See [Response](response.md#cookie) to set a cookie.

## Client IP and scheme

```dart
req.ip();       // client IP
req.scheme();   // http or https
req.isSecure(); // true for https
```

Behind a proxy, `req.ip()` shows the proxy, not the client.
Set `trustedProxies` in `AppConfig` to fix it. See [Deployment](../digging-deeper/deployment.md#https-put-a-proxy-in-front).

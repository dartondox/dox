# Request

## Typed input (recommended)

Ask for a [DTO](validation.md) in your controller. Dox reads the body (or the query for `GET`), checks it, and gives you a typed object.

```dart
class ApiController {
    Future<String> sayHello(HelloInput input) async {
        return 'Hello ${input.name}';
    }
}
```

Bad input gets `422` before your method runs. See [Validation](validation.md).

## Raw input

You can still read the raw values from the request.
`req.body['name']` and `req.input('name')` read the JSON body, the form data and the query string (`?foo=bar`).
These values are not checked.

```dart
class ApiController {
    String sayHello(DoxRequest req) {
        String name = req.input('name');
        return 'Hello $name';
    }
}
```

## Route param

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

The values are also in `req.param`. See [Controller: parameters](controller.md#parameters).

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

Without a DTO, `req.input('image')` gives the `RequestFile`, not checked.

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
    A file up to 1 MB stays in memory. A bigger file is streamed to a temp file while it arrives.
    The temp file is **deleted when the response is sent**.
    So call `store`, `moveTo` or `stream` before your controller returns.

### Size limits

A body that is too big gets `413 Payload Too Large`. Dox checks `Content-Length` first,
and also counts the bytes while reading.

```dart
AppConfig(
  maxBodySize: 10 * 1024 * 1024,        // JSON and urlencoded, default 10 MB
  maxMultipartSize: 100 * 1024 * 1024,  // form-data uploads, default 100 MB
);
```

Set the same limit in your proxy, like `client_max_body_size` in nginx.

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

Behind a proxy, set `trustedProxies` so these show the real client. See [Deployment](../digging-deeper/deployment.md#https-put-a-proxy-in-front).

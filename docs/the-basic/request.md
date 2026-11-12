---
icon: lucide/arrow-down-to-line
---

# Request

This page shows how to read input, files, headers and cookies from a request.

## Typed input (recommended)

Ask for a [DTO](validation.md) in your controller. Dox reads the body (or the query for `GET`, `HEAD` and `DELETE`), checks it, and gives you a typed object.

```dart
Route.put('/users/{id}', (UserController c) => c.update);

@Inject()
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
@Inject()
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
| `req.input('user.name', 'guest')` | a value inside a map or list, with a dot key. The second value is the default, used when the key is not there or is null. |
| `req.all()` | all values from the query string and the body, as a `Map` |
| `req.only(<String>['name', 'email'])` | only these keys |
| `req.except(<String>['password'])` | all values, without these keys |
| `req.has('name')` | `true` when the key is there as it is and not empty. It does not read dot keys. |
| `req.filled('name')` | `true` when the key is there and not empty. A text of only spaces, an empty list and an empty map count as empty. |
| `req.exists('name')` | `true` when the key is there, with any value (also `''` or null) |
| `req.missing('name')` | `true` when the key is not there |
| `req.boolean('remember')` | `true` for `true`, `1`, `on` and `yes`. Else `false`. |
| `req.integer('page', 1)` | the value as an `int`. The default is used when the key is not there or is not a number. |
| `req.body` | the body only (JSON, form data) |
| `req.query` | the query string only |
| `req.add('key', value)`, `req.merge({...})` | add values, for example in a middleware |

A dot key reads inside the input. `req.input('items.0.id')` gives the `id` of the first item.
A key that is in the input as it is wins. So a body key `'a.b'` is read before the `b` key inside `a`.
Dot keys also work in `filled`, `exists`, `missing`, `boolean`, `integer`, `file` and `hasFile`.
`has` does not read dot keys: `req.has('user.name')` is `false` for `{"user": {"name": "Ann"}}`. Use `filled` for that.

The flags `onlyPresent` and `hasKeyOnly` make `only` leave out missing keys and `has` only check the key. See [Core flags](../reference/app-config.md#core-flags).

Form and query keys with brackets give lists and maps:

| Input | `req.input(...)` gives |
| --- | --- |
| `tags[]=a&tags[]=b` | `req.input('tags')` is `['a', 'b']` |
| `address[city]=Yangon` | `req.input('address')` is `{'city': 'Yangon'}` |
| `items[0][name]=x` | `req.input('items')` is `[{'name': 'x'}]` |
| `name=a&name=b` (no brackets) | `req.input('name')` is `'b'`, the last value |

## Route params

Ask for a path param as a typed parameter, like `int id` in the example above.
The text values are also in `req.param`, like `req.param['id']`.
They are URL-decoded: `/users/a%20b` gives `'a b'`.
See [Controller: parameters](controller.md#parameters).

## Form data (File)

An uploaded file is a `RequestFile`. The request must be `multipart/form-data`.
Put the file in a DTO, so Dox checks its type and size:

```dart title="lib/app/dtos/upload_image/upload_image.dto.dart"
import 'package:dox_core/dox_core.dart';

part 'upload_image.dto.g.dart';

@Dto()
class UploadImage {
  @Image()
  @MaxSize('5MB')
  final RequestFile image;

  const UploadImage({required this.image});

  static const DtoSchema<UploadImage> schema = $UploadImageDto;
}
```

```dart title="lib/app/http/controllers/api.controller.dart"
@Inject()
class ApiController {
  Future<Map<String, String>> uploadImage(UploadImage input) async {
    String uploadedPath = await input.image.store('images');
    return <String, String>{'filename': uploadedPath};
  }
}
```

`store()` comes from the [`dox_storage`](../packages/storage.md) package. Add it and import `package:dox_storage/dox_storage.dart`.

Without a DTO, `req.file('image')` gives the `RequestFile`, or null when the field is not a file.
`req.hasFile('image')` is `true` when the field holds a file or a list of files.
For a field with many files, use `req.input('images')`. The file is not checked.

### `RequestFile`

```dart
RequestFile file = req.input('video');

file.filename;        // name from the client
file.filetype;        // content type, like video/mp4
file.extension;       // mp4
file.length;          // size in bytes
await file.size;      // size in KB
file.stream();        // read it in chunks
await file.store('videos');              // save to storage (needs dox_storage). returns the path
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
Map<String, dynamic> all = req.headers; // a repeated header is joined with ', '

req.userAgent();  // User-Agent header
req.host();       // Host header
req.origin();     // Origin header, or null
req.referer();    // Referer header, or null
req.isJson();     // true for a JSON body
req.isFormData(); // true for multipart/form-data
req.locale;       // first language of Accept-Language, like 'th', or null
req.bearerToken(); // the token of 'Authorization: Bearer <token>', or null
```

## Path and URL

```dart
req.path();                   // '/admin/users/5'
req.fullUrl();                // 'https://example.com/admin/users/5?tab=info'
req.pathIs('admin/*');        // true. `*` matches any text
req.routeIs('admin.users.*'); // true when the route name matches
```

`pathIs` cleans the path like the router does. A `/` at the start or the end does not matter, and `//` counts as one `/`. So `'admin/*'` and `'/admin/*'` are the same, and `/admin/` and `/admin//` match `'admin'`, like they reach the `/admin` route.
`routeIs` is `false` for a route with no name. Give a route a name with `.name('admin.users.show')`.

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

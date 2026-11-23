---
icon: lucide/arrow-down-to-line
---

# Request

The request gives you the input, files, headers and cookies that the client sent.

There are two ways to read input. You can ask for a typed, checked object (a DTO). Or you can read the raw values from `DoxRequest`. Use a DTO when you can, because Dox checks the input for you.

## Typed input (recommended)

Ask for a [DTO](dto.md) in your controller. Dox reads the body (or the query for `GET`, `HEAD` and `DELETE`), checks it, and gives you a typed object:

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

Bad input gets `422` before your method runs. See [DTOs](dto.md) and [Validation](validation.md).

## Raw input

Sometimes you need a value that is not in a DTO. Add a `DoxRequest` parameter to read the raw values. These values are **not** checked.

### Retrieving an input value

The `input` method reads one value from the query string or the body. The body wins when both have the key:

```dart
@Inject()
class ApiController {
  String sayHello(DoxRequest req) {
    String? name = req.input('name');
    return 'Hello $name';
  }
}
```

The second argument is the default. You get it when the key is not there or is null:

```dart
String name = req.input('name', 'guest');
```

To read inside a map or a list, use a dot key:

```dart
req.input('user.name');
req.input('items.0.id'); // the id of the first item
```

### Retrieving all input

The `all` method returns all values from the query string and the body, as a `Map`:

```dart
Map<String, dynamic> data = req.all();
```

If you want only the body or only the query string, use `body` or `query`:

```dart
req.body;  // JSON or form data
req.query; // the query string
```

### Retrieving a part of the input

Use `only` to get some keys, or `except` to get all keys but some:

```dart
req.only(<String>['name', 'email']);

req.except(<String>['password']);
```

### Checking if a value exists

The `filled` method returns `true` when the key is there and not empty. A text of only spaces, an empty list and an empty map count as empty:

```dart
if (req.filled('name')) {
  // ...
}
```

The `exists` method returns `true` when the key is there, with any value (also `''` or null). The `missing` method is the opposite:

```dart
req.exists('name');

req.missing('name');
```

There is also `has`. It returns `true` when the key is there as it is and not empty. It does not read dot keys, so `req.has('user.name')` is `false` for `{"user": {"name": "Ann"}}`. Use `filled` for that.

### Reading booleans and numbers

The `boolean` method returns `true` for `true`, `1`, `on` and `yes`, and `false` for anything else. This is useful for checkboxes:

```dart
bool remember = req.boolean('remember');
```

The `integer` method gives the value as an `int`. The default is used when the key is not there or is not a number:

```dart
int page = req.integer('page', 1);
```

### Adding input

Sometimes a middleware needs to add values to the input. Use `add` for one value, or `merge` for a map:

```dart
req.add('key', value);

req.merge(<String, dynamic>{'key': value});
```

### Lists and maps in forms

Form and query keys with brackets give lists and maps:

| Input | `req.input(...)` gives |
| --- | --- |
| `tags[]=a&tags[]=b` | `req.input('tags')` is `['a', 'b']` |
| `address[city]=Yangon` | `req.input('address')` is `{'city': 'Yangon'}` |
| `items[0][name]=x` | `req.input('items')` is `[{'name': 'x'}]` |
| `name=a&name=b` (no brackets) | `req.input('name')` is `'b'`, the last value |

## Route params

Ask for a path param as a typed parameter, like `int id` in the example above. See [Controller: parameters](controller.md#parameters).

The text values are also in `req.param`. They are URL-decoded, so `/users/a%20b` gives `'a b'`:

```dart
String? id = req.param['id'];
```

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

Then store it in the controller:

```dart title="lib/app/http/controllers/api.controller.dart"
@Inject()
class ApiController {
  Future<Map<String, String>> uploadImage(UploadImage input) async {
    String uploadedPath = await input.image.store('images');
    return <String, String>{'filename': uploadedPath};
  }
}
```

`store()` comes from the [`dox_storage`](../digging-deeper/file-storage.md) package. Add it and import `package:dox_storage/dox_storage.dart`.

!!! warning "Save the file before you return"
    A bigger upload is kept in a temp file, and the temp file is **deleted when the response is sent**.
    So call `store`, `moveTo` or `stream` before your controller returns.

### Files without a DTO

Without a DTO, `req.file` gives the `RequestFile`, or null when the field is not a file. These files are not checked:

```dart
RequestFile? image = req.file('image');
```

`hasFile` returns `true` when the field holds a file or a list of files. For a field with many files, use `req.input('images')`:

```dart
if (req.hasFile('image')) {
  // ...
}
```

### `RequestFile`

A `RequestFile` tells you about the file and lets you save it:

```dart
RequestFile file = req.input('video');

file.filename;        // name from the client
file.filetype;        // content type, like video/mp4
file.extension;       // mp4
file.length;          // size in bytes
await file.size;      // size in KB
```

To save the file, use `store` (needs `dox_storage`) or `moveTo`:

```dart
await file.store('videos');              // save to storage (needs dox_storage). returns the path
await file.moveTo('/data/videos/1.mp4'); // move it. returns the new File
```

To read the file, use `stream` to get it in chunks. `bytes` loads the whole file in memory, so avoid it for big files:

```dart
file.stream();        // read it in chunks
await file.bytes;     // the whole file in memory. avoid for big files
```

### Size limits

A body that is too big gets `413 Payload Too Large`. You can change the limits in `AppConfig`:

```dart title="lib/config/app.dart"
AppConfig(
  maxBodySize: 10 * 1024 * 1024,        // JSON and urlencoded, default 10 MB
  maxMultipartSize: 100 * 1024 * 1024,  // form-data uploads, default 100 MB
);
```

Set the same limit in your proxy, like `client_max_body_size` in nginx.

## Headers

The `header` method reads one header:

```dart
String? token = req.header('X-Token');
```

`headers` gives all of them. A repeated header is joined with `', '`:

```dart
Map<String, dynamic> all = req.headers;
```

There are short methods for common headers:

```dart
req.userAgent();  // User-Agent header
req.host();       // Host header
req.origin();     // Origin header, or null
req.referer();    // Referer header, or null
req.locale;       // first language of Accept-Language, like 'th', or null
req.bearerToken(); // the token of 'Authorization: Bearer <token>', or null
```

To check the body type, use `isJson` or `isFormData`:

```dart
req.isJson();     // true for a JSON body
req.isFormData(); // true for multipart/form-data
```

## Path and URL

Use `path` and `fullUrl` to read the URL of the request:

```dart
req.path();                   // '/admin/users/5'
req.fullUrl();                // 'https://example.com/admin/users/5?tab=info'
```

To check where the request goes, use `pathIs` with a pattern, or `routeIs` with a route name. `*` matches any text:

```dart
req.pathIs('admin/*');        // true. `*` matches any text
req.routeIs('admin.users.*'); // true when the route name matches
```

`routeIs` is `false` for a route with no name. Give a route a name with `.name('admin.users.show')`.

## Cookies

The `cookie` method reads a cookie. Dox encrypts cookies by default, so you get the decrypted value. For a cookie that is not encrypted, pass `decrypt: false`:

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

Behind a proxy, `req.ip()` shows the proxy, not the client. Set `trustedProxies` in `AppConfig` to fix it. See [Deployment](../digging-deeper/deployment.md#https-put-a-proxy-in-front).

## Details

- A key that is in the input as it is wins over a dot key. So a body key `'a.b'` is read before the `b` key inside `a`.
- Dot keys also work in `filled`, `exists`, `missing`, `boolean`, `integer`, `file` and `hasFile`.
- The flags `onlyPresent` and `hasKeyOnly` make `only` leave out missing keys and `has` only check the key. See [Core flags](../reference/app-config.md#core-flags).
- An upload up to 1 MB stays in memory. A bigger one is written to a temp file while it arrives.
- For the size limits, Dox checks `Content-Length` first. It also counts the bytes while it reads the body.
- `pathIs` cleans the path like the router does. A `/` at the start or the end does not matter, and `//` counts as one `/`. So `'admin/*'` and `'/admin/*'` are the same.

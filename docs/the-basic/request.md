---
icon: lucide/arrow-down-to-line
---

# Request

The request gives you the input, files, headers and cookies that the client sent.

## Typed input

Ask for a [DTO](dto.md) in your controller. Dox reads the body (or the query for GET, HEAD and DELETE), checks it, and gives you a typed object:

```dart
Route.put('/users/{id}', (UserController c) => c.update);

@Inject()
class UserController {
  Future<User?> update(int id, UpdateUser input) async {
    User? user = await User().find(id);
    user?.name = input.name;
    await user?.save();
    return user;
  }
}
```

Bad input gets 422 before your method runs. See [Validation](validation.md).

### Checking in the controller

To check the input at a later point, call `validate` with the DTO type:

```dart
CreateUser data = await req.validate<CreateUser>();
```

For input you know only at runtime, use a fluent schema. See [Fluent schemas](../packages/validation.md#fluent-schemas-for-dynamic-input):

```dart
Map<String, dynamic> data = await req.validateSchema(v.object(
    <String, Schema<Object?>>{'email': v.string().email()}));
```

## Raw input

Add a `DoxRequest` parameter to read the raw values. Dox does not check these values.

### Retrieving an input value

Read one value from the query string or the body. The body wins when both have the key:

```dart
String? name = req.input('name');
String name = req.input('name', 'guest'); // default for a missing key
```

Use a dot key to read inside a map or a list:

```dart
req.input('user.name');
req.input('items.0.id'); // the id of the first item
```

A key that is in the input as it is, like `'a.b'`, wins over a dot key.

### Retrieving all input

Get all values of the query string and the body:

```dart
Map<String, dynamic> data = req.all();
```

Get only the body or only the query string:

```dart
req.body;  // JSON or form data
req.query; // the query string
```

### Retrieving a part of the input

Get some keys, or all keys but some:

```dart
req.only(<String>['name', 'email']);
req.except(<String>['password']);
```

### Checking if a value exists

`filled` gives true when the key is there and not empty. Only spaces, an empty list and an empty map count as empty:

```dart
if (req.filled('name')) {
  // ...
}
```

`exists` gives true for a key with any value, also an empty string or null. `missing` is the opposite:

```dart
req.exists('name');
req.missing('name');
```

`has` gives true when the key is there and not empty. It does not read dot keys.

### Reading booleans and numbers

`boolean` gives true for true, 1, on and yes, so it works for checkboxes:

```dart
bool remember = req.boolean('remember');
```

`integer` gives the default when the key is missing or not a number:

```dart
int page = req.integer('page', 1);
```

### Adding input

Add one value, or a map of values, for example in a middleware:

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

Ask for a path param as a typed parameter, like `int id` above. See [Controller: parameters](controller.md#parameters).

The URL-decoded text values are also in `req.param`:

```dart
String? id = req.param['id'];
Map<String, String> params = req.pathParams; // {'id': '5'}
```

A value from [route model binding](routing.md#route-model-binding) comes from `bound`:

```dart
User user = req.bound<User>('user');
```

## Form data (File)

An uploaded file is a `RequestFile`. The request must be `multipart/form-data`. Put the file in a DTO, so Dox checks its type and size:

```dart title="lib/app/dtos/upload_image/upload_image.dto.dart"
@Dto()
class UploadImage {
  @Image()
  @MaxSize('5MB')
  final RequestFile image;

  const UploadImage({required this.image});

  static const DtoSchema<UploadImage> schema = $UploadImageDto;
}
```

Then store it. `store` comes from the [`dox_storage`](../digging-deeper/file-storage.md) package:

```dart
Future<Map<String, String>> uploadImage(UploadImage input) async {
  String path = await input.image.store('images');
  return <String, String>{'filename': path};
}
```

!!! warning "Save the file before you return"
    Dox deletes the temp file of a big upload when the response is sent.
    Call `store`, `moveTo` or `stream` before your controller returns.

### Files without a DTO

Get a file, or null when the field is not a file. Dox does not check it:

```dart
RequestFile? image = req.file('image');
```

`hasFile` gives true when the field holds a file or a list of files. For a field with many files, use `req.input('images')`:

```dart
if (req.hasFile('image')) {
  // ...
}
```

### Reading and saving a file {#requestfile}

A `RequestFile` tells you about the file:

```dart
file.filename;  // name from the client
file.filetype;  // content type, like video/mp4
file.extension; // mp4
file.length;    // size in bytes
await file.size; // size in KB
file.head;      // the first bytes, to find the real file type
```

Save it to storage, or move it:

```dart
await file.store('videos');              // gives the path
await file.moveTo('/data/videos/1.mp4'); // gives the new File
```

Read it in chunks with `stream`. `bytes` loads the full file in memory, so do not use it for big files:

```dart
file.stream();
await file.bytes;
```

`file.file` is the temp file on disk, or null when the upload is in memory. An upload up to 1 MB stays in memory.

### Size limits

A body that is too big gets 413. Change the limits in `AppConfig`:

```dart title="lib/config/app.dart"
AppConfig(
  maxBodySize: 10 * 1024 * 1024,       // JSON and urlencoded, default 10 MB
  maxMultipartSize: 100 * 1024 * 1024, // uploads, default 100 MB
);
```

Set the same limit in your proxy, like `client_max_body_size` in nginx.

## Headers

Read one header, or all of them. A repeated header is joined with `', '`:

```dart
String? token = req.header('X-Token');
Map<String, dynamic> all = req.headers;
```

There are short methods for common headers:

```dart
req.userAgent();   // User-Agent header
req.host();        // Host header
req.origin();      // Origin header, or null
req.referer();     // Referer header, or null
req.locale;        // first language of Accept-Language, like 'th', or null
req.bearerToken(); // the token of 'Authorization: Bearer <token>', or null
```

### Body type

Check the body type, or if the client wants a JSON answer:

```dart
req.isJson();      // true for a JSON body
req.isFormData();  // true for multipart/form-data
req.expectsJson(); // true for a JSON Accept header, JSON body or XHR
```

## Method, path and URL

Read the method and the URL of the request:

```dart
req.method;          // 'GET'
req.path();          // '/admin/users/5'
req.fullUrl();       // 'https://example.com/admin/users/5?tab=info'
req.uri;             // the Uri
req.protocolVersion; // '1.1', or '2.0' for HTTP/2
```

Check where the request goes. `*` matches any text, and a route with no name never matches `routeIs`:

```dart
req.pathIs('admin/*');        // a path pattern
req.routeIs('admin.users.*'); // a route name
```

## Cookies

Read a cookie. Dox encrypts cookies by default, so you get the decrypted value:

```dart
String? token = req.cookie('token');
String? raw = req.cookie('theme', decrypt: false); // value as sent
```

See [Response](response.md#cookie) to set a cookie.

## Client IP and scheme

```dart
req.ip();       // client IP
req.scheme();   // http or https
req.isSecure(); // true for https
```

Behind a proxy, set `trustedProxies` in `AppConfig`, or `req.ip()` gives the proxy. See [Deployment](../digging-deeper/deployment.md#https-put-a-proxy-in-front).

## Other request data

These come from middleware:

```dart
req.requestId; // from RequestId, see Middleware
req.session;   // from SessionMiddleware, see Session
req.hasSession; // true when the route has a session
req.auth;      // the logged in user, see Authentication
```

See [Middleware](middleware.md#request-id), [Session](session.md) and [Authentication](../security/authentication.md).

## Send the response yourself

Write the response on `req.httpRequest.response`. After `takeOverResponse`, Dox sends nothing more for the request:

```dart
Future<void> handle(DoxRequest req) async {
  req.takeOverResponse();
  HttpResponse res = req.httpRequest.response;
  res.write('done');
  await res.close();
}
```

Your code must close the response. `req.responseTakenOver` gives true after the call.

## Next steps

- [DTO](dto.md): typed and checked input.
- [Validation](validation.md): the rules for input.
- [Response](response.md): send an answer.

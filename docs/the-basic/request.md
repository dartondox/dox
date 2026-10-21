# Request

## Request body

You can use the map function to retrieve body data using `req.body['keyword']`. You can use the `req.body` to retrieve data from both JSON body and request parameters, like `?foo=bar`, by utilizing the map function.

```dart
class ApiController {
    sayHello(DoxRequest req) {
        String name = req.body['name']
        return 'Hello $name';
    }
}
```

## Route Param

Route parameters can be optional and can also be obtained from `req.param`.

```dart
Route.get('/hello/{name}');

class ApiController {
    sayHello(DoxRequest req, String name) {
        return 'Hello $name';
    }
}
```

## Form data (File)

An uploaded file is a `RequestFile`. Get it with `req.input('image')`.
The request must be `multipart/form-data`, with a file field named `image`.

```dart
class ApiController {
    Future<dynamic> uploadImage(DoxRequest req) async {
        req.validate({
            'image': 'required|image:png,jpg',
        });

        RequestFile image = req.input('image');
        String uploadedPath = await image.store('images');

        return {"filename" : uploadedPath};
    }
}
```

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

## Custom Form Request

#### Step 1. Create a request

```bash
dox create:request Blog
```

#### Step 2. Register in app

Register a request in `lib/config/app.dart`

```dart

formRequests: <Type, FormRequest Function()>{
    BlogRequest:() => BlogRequest(),
},
```

!!! info "Why?"
    If we don't utilize `dart:mirrors`, there isn't a straightforward method to instantiate a class from a string in Dart. Instead, we must register your request class in the `app.dart` file. As a result, Dox will seamlessly route the request to the corresponding controller.

#### Step 3. Usage

=== "blog.request.dart"

    ```dart
    import 'package:dox_core/dox_core.dart';

    class BlogRequest extends FormRequest {
        String? title;
        String? description;

        @override
        void setUp() {
            title = input('title');
            description = input('desc');
        }

        @override
        Map<String, String> rules() {
            return {
                'title': 'required',
            };
        }

        @override
        Map<String, String> messages() {
            return {
                'required': "The {field} is required"
            };
        }
    }
    ```

=== "blog.controller.dart"

    ```dart
    class BlogController {
        store(BlogRequest req) async {
            Blog blog = Blog();
            
            blog.title = req.title;
            blog.description = req.description;
            
            await blog.save();
            return blog;
        }
    }
    ```

#### `setUp`

Within this function, you have the opportunity to assign values to variables based on the incoming request, which can then be reused within the controller.

#### `rules`

This function serves as the location for defining validation rules for input requests.

#### `messages`

In this function, you have the ability to configure custom validation messages for input form request validation. Check [here](validation.md#custom-validation-message) for more about validation.

#### `schema`

Return a `dox_validation` schema to check the body with typed output. When `schema()` is not `null`, Dox uses it instead of `rules()`.
Build it once in a `static final` field, because `schema()` runs on every request.

```dart
class SignUpRequest extends FormRequest {
    static final ObjectSchema _schema = v.object(<String, Schema<Object?>>{
        'name': v.string().trim().min(3),
        'age': v.coerce.int().min(18),
    });

    @override
    ObjectSchema? schema() => _schema;
}
```

The schema (or the `rules()`) also becomes the request body in the [OpenAPI docs](../packages/openapi.md).

#### `validated`

The checked data, set before `setUp()` runs. With `schema()` it is the typed output. With `rules()` it is the fields that have rules.

```dart
store(SignUpRequest req) {
    int age = req.validated['age'];
}
```

!!! info
    A form request always validates with async support, so `unique` and `exists` rules work in `rules()`.

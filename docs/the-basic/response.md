# Response

The response can take various forms, including strings, maps, models, serializers, lists of models, and various types of exceptions.

=== "string"

    ```dart
    /// string
    class BlogController {
        index(DoxRequest req) {
            return 'pong';
        }
    }
    ```

=== "exception"

    ```dart
    /// exception
    class BlogController {
        index(DoxRequest req) {
            return InternalErrorException();
        }
    }
    ```

=== "map/json"

    ```dart
    /// map
    class BlogController {
        index(DoxRequest req) {
            return {"message" : "hello world!"};
        }
    }
    ```

=== "model"

    ```dart
    /// Model
    class BlogController {
        index(DoxRequest req) {
            Admin admin = await Admin().find(1)
            return admin;
        }
    }
    ```

=== "list of model"

    ```dart
    /// List<Model>
    class BlogController {
        index(DoxRequest req) {
            List admins = await Admin().all()
            return admins;
        }
    }
    ```

=== "file"

    ```dart
    /// File: streamed, with Content-Length and Range support
    class VideoController {
        show(DoxRequest req) {
            return File('storage/video.mp4');
        }
    }
    ```

=== "download"

    ```dart
    /// DownloadableFile
    class PdfController {
        download(DoxRequest req) async {
            DownloadableFile file = await Storage().download('filename.pdf');

            return file;
        }
    }
    ```

=== "stream"

    ```dart
    /// StreamFile
    class PdfController {
        download(DoxRequest req) async {
            StreamFile file = await Storage().stream('filename.pdf');

            return file;
        }
    }
    ```

!!! info
    Models and lists of models will be automatically converted into JSON format and arrays of JSON.

## Files and big responses

Return a `File` or a `Stream<List<int>>`. Dox pipes it to the client. It does not load it all into memory.

- A `File` sets `Content-Type` (from the file name), `Content-Length` and `Accept-Ranges`.
- It answers `Range: bytes=...` with `206 Partial Content`. Video players can seek, and downloads can resume.
- `Storage().stream()` and `Storage().download()` on the local disk also stream the file.

```dart
Route.get('/video', (DoxRequest req) => File('storage/video.mp4'));
```

## With

### Headers

=== "header"

    ```dart
    return response()
        .header('Authorization', 'Bearer xxxxxx')
        .header('ContentType', 'application/json');
    ```

=== "withHeaders"

    ```dart
    return response().withHeaders({
        'Authorization' : 'Bearer xxxxxx',
        'ContentType': 'application/json'
    });
    ```

### Status code

```dart
return response().statusCode(401);
```

### Content type

```dart
return response().contentType(ContentType.json);
```

### Stream

```dart
StreamFile file = await Storage().stream('filename.jpg');

return response().stream(file.stream).contentType(file.contentType);
```

### Cookie

=== "Set cookie"

    ```dart
    var cookie = DoxCookie('key', 'value');
    return response().cookie(cookie);
    ```

=== "With options"

    ```dart
    var cookie = DoxCookie(
        'token',
        'value',
        maxAge: Duration(days: 7), // sent as Max-Age in seconds. default 1 hour
        httpOnly: true,
        secure: true,
        path: '/',
    );
    return response().cookie(cookie);
    ```

=== "Get cookie"

    ```dart
    controllerMethod(DoxRequest req) {
        cookie = req.cookie(key)
    }
    ```

!!! info "Encrypt / Decrypt"
    By default, a cookie's value is encrypted and decrypted using the `APP_KEY`. You can opt to disable encryption by setting `encrypt: false` when setting a cookie and disable decryption by setting `decrypt: false` when retrieving a cookie, eg. `req.cookie(key, decrypt: false)`.
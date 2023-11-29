# File Storage

Dox file storage offers straightforward drivers for managing local file systems and extends the capability to develop custom drivers for cloud services like AWS or Digital Ocean Spaces.

```dart
Route.post('/image/put', (DoxRequest req) async {
    /// get form-data image from request
    RequestFile file = req.input('image');

    /// store image to /storage/images folder
    String url = await Storage().put('images', await file.bytes);

    return url;
});
```

## Functions

### `putRequestFile`

This function takes an instance of the RequestFile class as input and manages the storage of files. It is intended for handling files in a more structured manner, allowing you to work with file metadata, such as file name, content type, and other attributes, along with the file's binary data. This function is suitable for handling file uploads and storage in your application.


```dart
RequestFile file = req.input('image');

String url = await Storage().putRequestFile('images', file);
```

### `put`

This function accepts a byte sequence as input and stores it. It is designed for saving raw binary data, such as images or binary files, directly to a storage.

```dart
RequestFile file = req.input('image');

String url = await Storage().put('images', file.bytes);
```

### `get`

Retrieve the file in the form of a byte string.

```dart
List<int>? bytes = Storage().get('images/avatar/sample.jpeg');
```

### `exists`

Verify the file's existence.

```dart
List<int>? bytes = Storage().exists('images/avatar/sample.jpeg');
```

### `delete`

This function removes or erases the file.

```dart
List<int>? bytes = Storage().delete('images/avatar/sample.jpeg');
```

### `stream`

This function provides the file in a format that can be streamed.

```dart
StreamFile file = Storage().stream('images/avatar/sample.jpeg');
```


### `download`

This function provides the file in a format that can be downloaded.

```dart
DownloadableFile file = Storage().download('images/avatar/sample.jpeg');
```

## Custom file driver

To create a custom driver, you have the option to implement the `StorageDriverInterface`.

```dart
class YourCustomDriver implements StorageDriverInterface {

    @override
    Future<bool> exists(String filename) {
        
    }

    @override
    Future<Uint8List?> get(String filename) async {
        
    }

    @override
    Future<dynamic> delete(String filename) async {
        
    }

    @override
    Future<String> put(String folder, List<int> bytes, { String? extension }) async {

    }
}
```
---
icon: lucide/upload
---

# File upload

Accept an image from a form, check its size and type, save it to a disk, and return its URL.

An uploaded file can be too big, or of a different type than its name says. So this guide checks the file in a [DTO](../the-basic/dto.md) first, and then saves it.

## What you need

- A Dox app (`dox create my_app`). A new app has the `dox_storage` package, `lib/config/storage.dart` and `lib/providers/storage_provider.dart`.

## 1. Set up the disk

Give the `local` disk a `url`. `Storage().url()` uses it to make the public URL of a file:

```dart title="lib/config/storage.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/env.dart';

StorageConfig storageConfig = StorageConfig(
  defaultDisk: env.storageDisk,
  disks: <String, Map<String, dynamic>>{
    /// uploads go to the `storage` folder.
    /// `url` is the public address of `Storage.route('files', ...)`.
    'local': <String, dynamic>{
      'driver': 'local',
      'root': 'storage',
      'url': '${env.appUrl}/files',
    },
  },
);
```

Add a getter for the new `APP_URL` key to the `AppEnv` class:

```dart title="lib/config/env.dart"
  /// the public URL of this app, used in file links
  String get appUrl => 'http://localhost:3000';
```

Run `dart run build_runner build`. Then add `APP_URL=http://localhost:3000` to your `.env`.

The provider of a new app sets up the disks. Keep it as it is:

```dart title="lib/providers/storage_provider.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/storage.dart';

class AppStorageProvider extends StorageProvider {
  AppStorageProvider() : super(storageConfig);
}
```

## 2. Write the DTO

The DTO checks the file before the controller runs. A failed check answers 422:

```dart title="lib/app/dtos/upload_image/upload_image.dto.dart"
import 'package:dox_core/dox_core.dart';

part 'upload_image.dto.g.dart';

@Dto()
class UploadImage {
  /// jpg, jpeg, png, gif, webp or bmp. Dox reads the first bytes of the
  /// file to find the real type. The file name is not trusted.
  @Image()
  @MaxSize('5MB')
  final RequestFile image;

  const UploadImage({required this.image});

  static const DtoSchema<UploadImage> schema = $UploadImageDto;
}
```

For other file types, use `@Mimes(<String>['pdf', 'docx'])` in place of `@Image()`.

## 3. Write the controller

Save the file with `putFile`, and return its path and URL. `putFile` gives the file a new UUID name:

```dart title="lib/app/http/controllers/upload.controller.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/app/dtos/upload_image/upload_image.dto.dart';

@Inject()
class UploadController {
  /// POST /api/upload (multipart/form-data, field `image`)
  Future<Map<String, String>> store(UploadImage body) async {
    // saves the file as /images/<uuid>.<ext> on the default disk
    String path = await Storage().putFile('images', body.image);
    String url = await Storage().url(path);
    return <String, String>{'path': path, 'url': url};
  }
}
```

!!! warning "Save the file before you return"
    Dox deletes the uploaded temp file when it sends the response.
    So call `putFile`, `store` or `moveTo` in the controller, not later.

## 4. Add the routes

One route takes the upload. `Storage.route` serves the saved files at `/files/{key*}`:

```dart title="lib/routes/api.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/upload.controller.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    Route.post('/upload', (UploadController c) => c.store);
  }
}
```

```dart title="lib/routes/web.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_storage/dox_storage.dart';

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    // GET /files/{key*}, any file of the default disk
    Storage.route('files', signed: false);
  }
}
```

`signed: false` makes every file public. For private files, leave it out and use `Storage().signedUrl(path)` in place of `Storage().url(path)`.

## 5. Register the DTOs

Add the `dtos` list that `build_runner` writes. Skip this step if your `app.dart` already has `dtos: dtos`:

```dart title="lib/config/app.dart"
import 'package:my_app/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos,
  // ...
);
```

## 6. Build and run

Build the code and start the server:

```bash
dart run build_runner build --delete-conflicting-outputs
dox serve
```

## Check it

Upload a PNG:

```bash
curl -F image=@photo.png http://localhost:3000/api/upload
```

```json
{
  "path": "/images/074aa0d0-ce21-11f1-938a-57265e28c4a3.png",
  "url": "http://localhost:3000/files/images/074aa0d0-ce21-11f1-938a-57265e28c4a3.png"
}
```

Open the URL in the browser. The image shows.

Now upload a text file. You get 422:

```bash
curl -F image=@notes.txt http://localhost:3000/api/upload
```

```json
{"image":"The image must be an image"}
```

With no file, you also get 422, with `{"image":"The image is required"}`.

## Bigger files

A multipart body can be 100 MB by default. To change the limit, set `maxMultipartSize` in `AppConfig`. Set the same limit in your proxy too, like `client_max_body_size` in nginx.

## Next steps

- [Request: form data](../the-basic/request.md#form-data-file): read a `RequestFile`.
- [Validation rules: files](../the-basic/validation-rules.md#files): all the file rules.
- [File storage](../digging-deeper/file-storage.md): S3 and signed URLs.

---
icon: lucide/upload
---

# File upload

Accept an image from a form, check its size and type, save it to a disk, and return its URL.

You should never trust an uploaded file: it can be too big, or it can be a different type than its name says. So this guide checks the file in a [DTO](../the-basic/dto.md) first, and only then saves it.

## What you need

- A Dox app (`dox create my_app`). A new app has the `dox_storage` package, `lib/config/storage.dart` and `lib/providers/storage_provider.dart`.

## 1. Set up the disk

The `local` disk of a new app saves files in the `storage` folder. Give the disk a `url`, because `Storage().url()` uses it to build the public URL of a file:

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

`APP_URL` is a new key, so add a getter for it to the `AppEnv` class:

```dart title="lib/config/env.dart"
  /// the public URL of this app, used in file links
  String get appUrl => 'http://localhost:3000';
```

Run `dart run build_runner build` to update `env.g.dart`. Then add `APP_URL=http://localhost:3000` to your `.env`.

The provider of a new app sets up the disks. You do not need to change it:

```dart title="lib/providers/storage_provider.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/storage.dart';

class AppStorageProvider extends StorageProvider {
  AppStorageProvider() : super(storageConfig);
}
```

## 2. Write the DTO

The DTO checks the file before your controller runs. If the check fails, Dox answers `422` and the controller never sees the file.

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

If you want other file types, use `@Mimes(<String>['pdf', 'docx'])` in place of `@Image()`.

## 3. Write the controller

The controller saves the file with `putFile` and returns its path and URL. `putFile` gives the file a new UUID name, and on the local disk it does not read the whole file into memory.

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
    Dox deletes the uploaded temp file when the response is sent.
    So call `putFile`, `store` or `moveTo` inside the controller, not later.

## 4. Add the routes

You need two routes. One route takes the upload, and `Storage.route` serves the saved files at `GET /files/{key*}`:

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

`signed: false` makes every file public. If the files are private, leave it out, so the route serves only signed URLs. Then use `Storage().signedUrl(path)` in place of `Storage().url(path)`.

## 5. Register the DTOs

Dox finds a DTO in the `dtos` list of `AppConfig`. `build_runner` writes this list to `lib/generated/dtos.g.dart`. You add it only once, so skip this step if your `app.dart` already has `dtos: dtos`.

```dart title="lib/config/app.dart"
import 'package:my_app/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos,
  // ...
);
```

## 6. Build and run

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
{"path":"/images/074aa0d0-ce21-11f1-938a-57265e28c4a3.png","url":"http://localhost:3000/files/images/074aa0d0-ce21-11f1-938a-57265e28c4a3.png"}
```

Open the `url` in the browser. The image shows.

Now upload a text file. You get `422`:

```bash
curl -F image=@notes.txt http://localhost:3000/api/upload
```

```json
{"image":"The image must be an image"}
```

If you send no file at all, you also get `422`, with `{"image":"The image is required"}`.

## Bigger files

A `multipart/form-data` body can be 100 MB by default. If you need more, change it in `AppConfig(maxMultipartSize: ...)`. Set the same limit in your proxy too (`client_max_body_size` in nginx).

## Details

- `@Image()` reads the first bytes of the file to find the real type. It does not trust the file name.
- A file bigger than 1 MB is written to a temp file while it arrives. That is the file Dox deletes after the response.
- On the local disk, `putFile` moves the temp file. With `permissions` on, it streams the file in place of a move.

## See also

- [Request: form data](../the-basic/request.md#form-data-file) for `RequestFile`
- [Validation rules: files](../the-basic/validation-rules.md#files) for `@Image`, `@Mimes`, `@MimeTypes`, `@MaxSize`, `@MinSize`, `@Dimensions`
- [File storage](../digging-deeper/file-storage.md) for S3 and signed URLs

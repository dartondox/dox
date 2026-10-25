---
icon: lucide/upload
---

# File upload

Accept an image from a form, check its size and type, save it to a disk, and return its URL.

## What you need

- A Dox app (`dox create my_app`).
- `build_runner` for the DTO (a new app has it).

## 1. Set up the disk

Give the `local` disk a `url`. `Storage().url()` uses it to build the public URL of a file.

```dart title="lib/config/storage.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

StorageConfig storage = StorageConfig(
  defaultDisk: env.storageDisk,
  disks: <String, Map<String, dynamic>>{
    /// uploads go to the `storage` folder.
    /// `url` is the public address of `Route.files('files', ...)`.
    'local': <String, dynamic>{
      'driver': 'local',
      'root': 'storage',
      'url': '${env.appUrl}/files',
    },
  },
);
```

`APP_URL` is a new key. Add a getter for it to the `AppEnv` class:

```dart title="lib/config/env.dart"
  /// the public URL of this app, used in file links
  String get appUrl => 'http://localhost:3000';
```

Run `dart run build_runner build` to update `env.g.dart`.
Then add `APP_URL=http://localhost:3000` to your `.env`.

## 2. Write the DTO

The DTO checks the file before your controller runs.

```dart title="lib/app/http/dtos/upload_image.dto.dart"
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

`putRequestFile` moves the upload to the disk with a new UUID name. It does not read the file into memory.

```dart title="lib/app/http/controllers/upload.controller.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/dtos/upload_image.dto.dart';

@Inject()
class UploadController {
  /// POST /api/upload (multipart/form-data, field `image`)
  Future<Map<String, String>> store(UploadImage body) async {
    // saves the file as /images/<uuid>.<ext> on the default disk
    String path = await Storage().putRequestFile('images', body.image);
    String url = await Storage().url(path);
    return <String, String>{'path': path, 'url': url};
  }
}
```

!!! warning "Save the file before you return"
    A file bigger than 1 MB is written to a temp file while it arrives.
    Dox deletes that temp file when the response is sent.
    So call `putRequestFile`, `store` or `moveTo` inside the controller, not later.

## 4. Add the routes

One route takes the upload. `Route.files` serves the saved files at `GET /files/{key*}`.

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

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    // GET /files/{key*}, any file of the default disk
    Route.files('files', signed: false);
  }
}
```

`signed: false` makes every file public. Leave it out to serve only signed URLs. Then use `Storage().signedUrl(path)` in place of `Storage().url(path)`.

## 5. Build and run

```bash
dart run build_runner build --delete-conflicting-outputs
dox serve
```

Make sure `lib/config/app.dart` has `dtos: dtos` from `lib/generated/dtos.g.dart`. See [Validation: setup](../the-basic/validation.md#setup).

## Check it

Upload a PNG:

```bash
curl -F image=@photo.png http://localhost:3000/api/upload
```

```json
{"path":"/images/074aa0d0-ce21-11f1-938a-57265e28c4a3.png","url":"http://localhost:3000/files/images/074aa0d0-ce21-11f1-938a-57265e28c4a3.png"}
```

Open the `url` in the browser. The image shows.

Upload a text file. You get `422`:

```bash
curl -F image=@notes.txt http://localhost:3000/api/upload
```

```json
{"image":"The image must be an image"}
```

Send no file at all. You get `422` with `{"image":"The image is required"}`.

## Bigger files

The default limit for a `multipart/form-data` body is 100 MB. Change it in `AppConfig(maxMultipartSize: ...)`.
Set the same limit in your proxy (`client_max_body_size` in nginx).

## See also

- [Request: form data](../the-basic/request.md#form-data-file) for `RequestFile`
- [Validation: files](../the-basic/validation.md#files) for `@Image`, `@Mimes`, `@MaxSize`
- [File storage](../digging-deeper/file-storage.md) for S3 and signed URLs

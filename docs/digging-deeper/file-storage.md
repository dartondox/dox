---
icon: lucide/hard-drive
---

# File Storage

`Storage()` saves and reads files on a disk: the local folder, AWS S3 (and R2, MinIO, Spaces), or memory.

It is in the [`dox_storage`](../packages/storage.md) package. Add it to your app:

```bash
dart pub add dox_storage
```

```dart
import 'package:dox_storage/dox_storage.dart';

Route.post('/avatar', (DoxRequest req) async {
  RequestFile file = req.input('avatar');
  String path = await Storage().putRequestFile('avatars', file);
  return <String, String>{'path': path}; // /avatars/<uuid>.png
});
```

## Config

Without a config, `Storage()` has one disk: `local`, in the `storage` folder.
To add disks, make `lib/config/storage.dart`:

```dart title="lib/config/storage.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/env.dart';

StorageConfig storageConfig = StorageConfig(
  defaultDisk: env.storageDisk,
  disks: <String, Map<String, dynamic>>{
    'local': <String, dynamic>{
      'driver': 'local',
      'root': 'storage',
      'url': 'https://app.test/files', // for url() and signedUrl()
    },
    's3': <String, dynamic>{
      'driver': 's3',
      'bucket': env.awsBucket,
      'region': env.awsDefaultRegion,
      'key': env.awsAccessKeyId,
      'secret': env.awsSecretAccessKey,
      'endpoint': env.awsEndpoint, // R2, MinIO, Spaces
    },
    'memory': <String, dynamic>{'driver': 'memory'},
  },
);
```

The `s3` disk reads five keys that a new project does not have yet. Add them to
`lib/config/env.dart` and run `dart run build_runner build`. They are nullable,
so the app starts without them:

```dart title="lib/config/env.dart"
  String? get awsBucket;

  String get awsDefaultRegion => 'us-east-1';

  String? get awsAccessKeyId;

  String? get awsSecretAccessKey;

  /// R2, MinIO or Spaces. Null for AWS.
  String? get awsEndpoint;
```

Then add the provider. It sets the disks in every isolate. Put it in `lib/`, so the generated container finds it:

```dart title="lib/providers/storage_provider.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/storage.dart';

class AppStorageProvider extends StorageProvider {
  AppStorageProvider() : super(storageConfig);
}
```

| Driver | Options |
| --- | --- |
| `local` | `root` (default `storage`), `url`, `app_key` (default: your APP_KEY), `visibility` |
| `s3` | `bucket`, `region`, `key`, `secret`, `token`, `endpoint`, `path_style` (MinIO), `url` (CDN), `visibility`, `acl`, `batch_delete` |
| `memory` | none. For tests |

The `s3` disk needs `bucket`, `key` and `secret`. When one is missing, the first use of the disk throws an `ArgumentError` that names the setting.

## Functions

```dart
// save with a new uuid file name, returns '/images/<uuid>.png'
String path = await Storage().put('images', bytes, extension: 'png');
String path2 = await Storage().putRequestFile('images', file);

Uint8List? bytes = await Storage().get(path);  // null when missing
bool found = await Storage().exists(path);
await Storage().delete(path);

String url = await Storage().url(path);         // needs the disk `url` option
String signed = await Storage().signedUrl(path, expiresIn: Duration(minutes: 10));

// another disk
await Storage().disk('s3').put('reports', bytes, extension: 'pdf');
```

`putRequestFile` on the local disk moves the upload temp file. It does not read it into memory.

`putRequestFile` and `file.store()` take the extension from the file name. When the bytes are a known format (png, jpg, pdf, zip, ...) that does not match the name, the extension of the bytes is used. So a png sent as `a.html` is saved as `.png` and is never served as a web page.

### `stream` and `download`

```dart
Route.get('/photo', (DoxRequest req) {
  return Storage().stream(req.input('path'));    // shown in the browser
});

Route.get('/report', (DoxRequest req) {
  return Storage().disk('s3').download('reports/2024.pdf'); // saved as a file
});
```

Both read the file as a stream, from any disk, with `Content-Length`.
A big file is never loaded into memory. A missing file answers `404`.

### Full disk API

`Storage().use('s3')` returns the `dox_storage` `Disk`: `copy`, `move`, `listAll`, `getMetaData`,
`putStream`, `setVisibility` and more. See [dox_storage](../packages/storage.md).

## Serve local signed URLs

```dart
// lib/routes/web.dart
Storage.route('files');                    // GET /files/{key*}, signed URLs only
Storage.route('public', signed: false);    // any file of the disk
Storage.route('docs', disk: 'memory');     // another disk than the default
Storage.route('uploads', download: true);  // every file is a download
```

An html, svg, xml or javascript file is always sent as a download in a sandbox, so its script does not run on your site.
Every file has `X-Content-Type-Options: nosniff`.

```dart
String url = await Storage().signedUrl('invoices/1.pdf'); // https://app.test/files/invoices/1.pdf?expires=...&signature=...
```

A missing, wrong or expired signature answers `403`.
Set the disk `url` option to the full URL of the route (`https://app.test/files`).

## Tests

To swap a disk with a memory disk in tests, see [Testing](testing.md#test-file-storage).

## Your own driver

Implement `DriverContract` from `package:dox_storage/dox_storage.dart`. Register it in a [provider](providers.md), so every isolate has it:

```dart
Storage.manager.register('dropbox', DropboxDriver());
await Storage().disk('dropbox').put('notes', bytes, extension: 'txt');
```

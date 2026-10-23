# File Storage

`Storage()` saves and reads files on a disk: the local folder, AWS S3 (and R2, MinIO, Spaces), or memory.
It runs on [`dox_storage`](../packages/storage.md), which is built into `dox_core`.

```dart
Route.post('/avatar', (DoxRequest req) async {
  RequestFile file = req.input('avatar');
  String path = await Storage().putRequestFile('avatars', file);
  return <String, String>{'path': path}; // /avatars/<uuid>.png
});
```

## Config

Without a config, Dox has one disk: `local`, in the `storage` folder.
To add disks, make `lib/config/storage.dart`:

```dart title="lib/config/storage.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

StorageConfig storage = StorageConfig(
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
so the app still starts without them when you do not use S3:

```dart title="lib/config/env.dart"
  String? get awsBucket;

  String get awsDefaultRegion => 'us-east-1';

  String? get awsAccessKeyId;

  String? get awsSecretAccessKey;

  /// R2, MinIO or Spaces. Null for AWS.
  String? get awsEndpoint;
```

Then pass it to `AppConfig(storage: storage)` in `lib/config/app.dart`.

| Driver | Options |
| --- | --- |
| `local` | `root` (default `storage`), `url`, `app_key` (default: your APP_KEY), `visibility` |
| `s3` | `bucket`, `region`, `key`, `secret`, `token`, `endpoint`, `path_style` (MinIO), `url` (CDN), `visibility`, `acl`, `batch_delete` |
| `memory` | none. For tests |

The `s3` disk needs `bucket`, `key` and `secret`. When one is missing, the first use of the disk throws an error.

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
Route.files('files');                    // GET /files/{key*}, signed URLs only
Route.files('public', signed: false);    // any file of the disk
Route.files('docs', disk: 'memory');     // another disk than the default
```

```dart
String url = await Storage().signedUrl('invoices/1.pdf'); // https://app.test/files/invoices/1.pdf?expires=...&signature=...
```

A missing, wrong or expired signature answers `403`.
Set the disk `url` option to the full URL of the route (`https://app.test/files`).

## Tests

`Dox().storage` is the `DriveManager` that `Storage()` uses. `fake(name)` swaps a disk with an empty memory disk:

```dart
Disk fake = Dox().storage.fake('s3');
await uploadReport();
expect(await fake.exists('reports/2024.pdf'), isTrue);
Dox().storage.restore('s3');
```

`Disk` keys have no `/` at the start. See [Testing](testing.md).

## Your own driver

Implement `DriverContract` from `package:dox_storage/dox_storage.dart`. Register it in a [service](services.md), so every isolate has it:

```dart
Dox().storage.register('dropbox', DropboxDriver());
await Storage().disk('dropbox').put('notes', bytes, extension: 'txt');
```

---
icon: lucide/hard-drive
---

# File Storage

`Storage()` saves and reads files on a disk: a local folder, AWS S3 (and R2, MinIO, Spaces), or memory.

All disks have the same methods. So you can use a local folder in development and S3 in production, with the same code. Storage is in the `dox_storage` package. You can also use it [without Dox](#without-dox).

```dart
import 'package:dox_storage/dox_storage.dart';

Route.post('/avatar', (DoxRequest req) async {
  RequestFile file = req.input('avatar');
  String path = await Storage().putFile('avatars', file);
  return <String, String>{'path': path}; // /avatars/<uuid>.png
});
```

## Setup

A new project already has storage. In an older project, run this command:

```bash
dox add storage
```

It writes `lib/config/storage.dart`, the provider, the `storage` folder and the `STORAGE_DISK=local` key. It never overwrites a file.

Add `--disk=s3` to also add an `s3` disk and the `AWS_*` keys. `STORAGE_DISK` stays `local`, so fill in the keys first, then set `STORAGE_DISK=s3`.

### Configuration

The disks are in `lib/config/storage.dart`. `STORAGE_DISK` in `.env` picks the default disk. This example adds a `url` to the local disk, an `s3` disk and a `memory` disk:

```dart title="lib/config/storage.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/env.dart';

StorageConfig storageConfig = StorageConfig(
  defaultDisk: env.storageDisk,
  disks: <String, Map<String, dynamic>>{
    'local': <String, dynamic>{
      'driver': 'local',
      'root': 'storage',
      // for signedUrl(). Without it, url() gives /storage/<path>
      'url': 'https://app.test/files',
    },

    /// only when AWS_BUCKET is set
    if (env.awsBucket != null)
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

| Driver | Use for | Options |
| --- | --- | --- |
| `local` | a folder on the server | `root` (default `storage`), `url`, `app_key` (default: your APP_KEY), `visibility`, `atomic_writes`, `permissions` |
| `s3` | AWS S3, Cloudflare R2, MinIO, DigitalOcean Spaces, GCS | `bucket`, `region`, `key`, `secret`, `token`, `endpoint`, `path_style` (MinIO), `url` (CDN), `visibility`, `acl`, `batch_delete`, `unsigned_payload` |
| `memory` | tests | none |

Signed upload URLs work only on S3. The memory disk gives fake URLs.

The provider in `lib/providers/` sets up these disks in every isolate:

```dart title="lib/providers/storage_provider.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/storage.dart';

class AppStorageProvider extends StorageProvider {
  AppStorageProvider() : super(storageConfig);
}
```

### The S3 disk

Add the S3 keys to `lib/config/env.dart`, then run `dart run build_runner build`. The `s3` disk is added only when `AWS_BUCKET` is set:

```dart title="lib/config/env.dart"
  String? get awsBucket;

  String get awsDefaultRegion => 'us-east-1';

  String? get awsAccessKeyId;

  String? get awsSecretAccessKey;

  /// R2, MinIO or Spaces. Null for AWS.
  String? get awsEndpoint;
```

Without `bucket`, `key` or `secret`, the app stops at start with an ArgumentError. To save CPU on big uploads, set `'unsigned_payload': true`. The signature then does not cover the body, so use it only over HTTPS.

### Atomic writes

A local disk writes a file in place. With `atomic_writes`, it writes a temp file and renames it, so a failed upload never leaves a partial file:

```dart
'local': <String, dynamic>{
  'driver': 'local',
  'root': 'storage',
  'atomic_writes': true,
},
```

The rename makes a new file, so the file gets the default mode and owner.

## Using another disk

`Storage()` uses the default disk. Use `disk` to pick another one:

```dart
await Storage().disk('s3').put('reports/2026.pdf', bytes, exact: true);
```

## Storing files

`putFile` saves a file in a folder with a new uuid name, and returns the path. It takes a `RequestFile` or bytes. For bytes, give `extension:`, or Dox finds it from the bytes:

```dart
// returns '/images/<uuid>.png'
String path = await Storage().putFile('images', file); // a RequestFile
Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
String path2 =
    await Storage().putFile('images', bytes, extension: 'png');
String path3 =
    await Storage().put('images', bytes, extension: 'png'); // like putFile
```

When the bytes are a known format, like png, the extension of the bytes wins over the file name. So a png sent as `a.html` is saved as `.png`.

### Storing with your own name

`putFileAs` uses your file name. It replaces an old file with that name:

```dart
String path4 = await Storage().putFileAs('avatars', file, 'user-1.png');
```

Do not use the file name from the client, because the name is used as it is.

### Storing at an exact path

`put` with `exact: true` writes to an exact path. It takes a string, a `List<int>` or a `Stream<List<int>>`:

```dart
await Storage().put('notes/a.txt', 'hello', exact: true);
```

### Storing uploaded files

An uploaded file can store itself. `store` works like `putFile`, and `storeAs` works like `putFileAs`:

```dart
RequestFile file = req.input('image');
String path = await file.store('images');
String onS3 = await file.store('images', disk: 's3');
String avatar = await file.storeAs('avatars', 'user-1.png');
```

`putRequestFile` and `putRequestFileAs` on `Storage()` do the same:

```dart
String path = await Storage().putRequestFile('images', file);
String avatar =
    await Storage().putRequestFileAs('avatars', 'user-1.png', file);
```

On a local disk, the upload temp file is moved, not read into memory.

### Prepending and appending

Add text to the end or the start of a file. A missing file is made:

```dart
await Storage().append('logs/app.log', 'new line');
await Storage().prepend('logs/app.log', 'first line');
```

A new line goes between the old and the new text. Change it with `separator`. Two writers at the same time can lose a write.

## Retrieving files

`get` gives the bytes of a file, or null when the file is missing:

```dart
Uint8List? found = await Storage().get(path);
```

### Checking if a file exists

`exists` checks for a file. `missing` is the opposite:

```dart
bool exists = await Storage().exists(path);
bool gone = await Storage().missing(path);
```

### File metadata

`size` gives the size in bytes, and `lastModified` gives the time of the last change. Both throw `FileNotFoundException` when the file is missing:

```dart
int size = await Storage().size(path);
DateTime changed = await Storage().lastModified(path);
```

## Downloading files

`stream` shows a file in the browser, and `download` makes the browser save it. Both stream the file, and a missing file answers 404:

```dart
Route.get('/photo', (DoxRequest req) {
  return Storage().stream(req.input('path'));
});

Route.get('/report', (DoxRequest req) {
  return Storage().disk('s3').download('reports/2024.pdf');
});
```

`download` uses the last part of the path as the file name. Give `name:` to use another name:

```dart
Route.get('/invoice', (DoxRequest req) {
  return Storage().download('invoices/42.pdf', name: 'Invoice 42.pdf');
});
```

To add headers, put the download in a `response()`:

```dart
Route.get('/invoice', (DoxRequest req) async {
  DownloadableFile file = await Storage().download('invoices/42.pdf');
  return response(file).header('Cache-Control', 'no-store');
});
```

## File URLs

`url` gives the URL of a file. On a local disk with no `url` option, it gives `/storage/<path>`:

```dart
String url = await Storage().url(path);
```

Dox serves that URL only with `Storage.route('storage', signed: false)`. See [Serving local files](#serving-local-files).

### Signed URLs

A signed URL opens a file for a short time, like a private invoice. `temporaryUrl` is the same as `signedUrl`:

```dart
String signed =
    await Storage().signedUrl(path, expiresIn: Duration(minutes: 10));
String same = await Storage().temporaryUrl(path);
```

On a local disk, `signedUrl` needs the disk `url` option: the full URL of the route, like `https://app.test/files`.

### Serving local files

`Storage.route` adds a route that serves the files of a disk:

```dart title="lib/routes/web.dart"
Storage.route('files');                  // GET /files/{key*}, signed only
Storage.route('public', signed: false);  // any file of the disk
Storage.route('docs', disk: 'memory', signed: false); // another disk
Storage.route('uploads', download: true); // every file is a download
```

A signed URL of the `files` route looks like this:

```dart
String url = await Storage().signedUrl('invoices/1.pdf');
// https://app.test/files/invoices/1.pdf?expires=...&signature=...
```

A missing, wrong or expired signature answers 403. Signed routes work only on a `local` disk. An html, svg, xml or javascript file is always sent as a download in a sandbox, so its script cannot run on your site.

## Copying and moving files

`copy` and `move` replace an old file at the new path:

```dart
await Storage().copy('notes/a.txt', 'backup/a.txt');
await Storage().move('backup/a.txt', 'old/a.txt');
```

On S3, the copy runs inside S3. A missing source file answers 404.

## Deleting files

```dart
await Storage().delete(path);
```

## Directories

`files` gives the files in a folder, `allFiles` also gives the files in sub-folders, and `directories` gives the sub-folders. Each path starts with `/`:

```dart
List<String> files = await Storage().files('images');
List<String> all = await Storage().allFiles('images');
List<String> folders = await Storage().directories('images');
```

`directoryExists` checks for a folder. On S3 and memory disks, a folder exists when a file is in it:

```dart
bool folder = await Storage().directoryExists('images');
```

`makeDirectory` makes a folder. It works only on a local disk:

```dart
await Storage().makeDirectory('reports');
```

`deleteDirectory` deletes a folder and all files in it:

```dart
await Storage().deleteDirectory('old');
```

The root (`''` or `/`) throws `InvalidKeyException`. To empty a full disk, use `Storage().use().deleteAll()`.

## File visibility

A file is public or private. Use `setVisibility` and `getVisibility`:

```dart
await Storage().setVisibility(path, Visibility.private);
Visibility visibility = await Storage().getVisibility(path);
```

On S3, `setVisibility` sets the ACL. With `'acl': false` (R2 and similar), it does nothing, and `getVisibility` gives the disk `visibility`. On a local disk it is the same, unless you turn on `permissions`.

### Visibility on a local disk

Add `'permissions': true` to use file modes. Then `setVisibility` runs `chmod`, and `getVisibility` reads the mode:

```dart
'local': <String, dynamic>{
  'driver': 'local',
  'root': 'storage',
  'permissions': true,
},
```

The modes are: public file `0644`, private file `0600`, public folder `0755`, private folder `0700`. On Windows, `permissions` does nothing.

### Custom file modes

Give `permissions` a map with a `file` and a `dir` key. Dart has no octal numbers, so write the modes in hex: `0x1a0` is `0640`:

```dart
'private': <String, dynamic>{
  'driver': 'local',
  'root': 'storage-private',
  'visibility': 'private',
  'permissions': <String, dynamic>{
    'file': <String, int>{'public': 0x1a4, 'private': 0x1a0},
    'dir': <String, int>{'public': 0x1ed, 'private': 0x1e8},
  },
},
```

A mode you leave out keeps its default. A mode that is not an int from 0 to 0x1ff throws an ArgumentError.

## The disk API

`Storage()` has short methods for common work. For more control, get a `Disk` with `use`. With no name, you get the default disk:

```dart
Disk disk = Storage().use('s3');
```

A `Disk` also has `get`, `exists`, `missing`, `delete`, `copy`, `move`, `size`, `lastModified`, `append`, `prepend`, `files`, `allFiles`, `directories`, `directoryExists`, `makeDirectory`, `deleteDirectory`, `getVisibility` and `setVisibility`. Its `get` throws `FileNotFoundException` when the file is missing.

### Write options

`put` on a `Disk` writes to the exact key. `WriteOptions` sets the content type and the visibility. `copy` and `move` also take `options:`:

```dart
await disk.put('a.json', '{}',
    options: WriteOptions(
        contentType: 'application/json', visibility: Visibility.public));
```

### Storing big files

`putStream` writes a stream, so the file is not loaded into memory:

```dart
await disk.putStream('videos/big.mp4', File('big.mp4').openRead());
```

On S3, `put` has a limit of 5 GiB. `putStream` uses a multipart upload with parts of `multipartPartSize` (8 MiB, a field of `S3DriverConfig`), up to about 78 GiB.

### Reading text and streams

`getString` reads a file as text. For a big file, use `getStream`. Both throw `FileNotFoundException` when the file is missing:

```dart
String text = await disk.getString('notes/a.txt');

Stream<List<int>> stream = await disk.getStream('videos/big.mp4');
```

`getStreamWithMetaData` gives the stream and the metadata together. On S3 it is one request:

```dart
ObjectStream file = await disk.getStreamWithMetaData('videos/big.mp4');
// file.stream, file.metaData
```

### All metadata in one call

`getMetaData` gives the size, content type, last change time and etag:

```dart
ObjectMetaData meta = await disk.getMetaData('avatars/1.png');
```

### Public URLs

`getUrl` gives the public URL of a file:

```dart
String url = await disk.getUrl('avatars/1.png');
```

### Deleting many files

`deleteAll` removes all files under a prefix. With `''` or no argument, it empties the disk:

```dart
await disk.deleteAll('avatars');
```

### Listing page by page

For a big folder, read one page at a time with `listAll`:

```dart
ListResult page = await disk.listAll('avatars',
    ListOptions(recursive: true, limit: 100));
// next page: ListOptions(paginationToken: page.paginationToken)
```

### Signed URL options

`getSignedUrl` takes `SignedUrlOptions`. `expiresIn` is 30 minutes by default, and on S3 the maximum is 7 days. `contentDisposition` sets the header of the download:

```dart
String signed = await disk.getSignedUrl('avatars/1.png',
    options: SignedUrlOptions(expiresIn: Duration(minutes: 10)));
```

### Signed upload URLs

On S3, the browser can upload a file directly to the bucket with a signed upload URL:

```dart
String upload = await disk.getSignedUploadUrl('avatars/2.png',
    options: SignedUrlOptions(contentType: 'image/png'));
```

## S3-compatible services

These examples use `S3DriverConfig`, the class behind an `s3` disk. In a Dox config, the same settings are the disk keys `endpoint`, `path_style`, `acl` and `batch_delete`. See [Configuration](#configuration).

### Cloudflare R2

R2 does not take ACL headers, so set `supportsAcl: false`:

```dart
S3DriverConfig(
  bucket: 'my-bucket',
  region: 'auto',
  endpoint: 'https://<account-id>.r2.cloudflarestorage.com',
  accessKeyId: '...',
  secretAccessKey: '...',
  supportsAcl: false,
);
```

### MinIO

MinIO needs path style URLs:

```dart
S3DriverConfig(
  bucket: 'my-bucket',
  region: 'us-east-1',
  endpoint: 'http://localhost:9000',
  forcePathStyle: true,
  accessKeyId: 'minioadmin',
  secretAccessKey: 'minioadmin',
);
```

### DigitalOcean Spaces

Put the region of your space in `region` and in the endpoint:

```dart
S3DriverConfig(
  bucket: 'my-space',
  region: 'nyc3',
  endpoint: 'https://nyc3.digitaloceanspaces.com',
  accessKeyId: '...',
  secretAccessKey: '...',
);
```

### Google Cloud Storage

GCS does not take ACL headers or the S3 batch delete call:

```dart
S3DriverConfig(
  bucket: 'my-bucket',
  region: 'auto',
  endpoint: 'https://storage.googleapis.com',
  accessKeyId: 'GOOG...',
  secretAccessKey: '...',
  supportsAcl: false,
  supportsBatchDelete: false,
);
```

## Custom drivers

Implement `DriverContract`, and register it in a [provider](providers.md) so every isolate has it:

```dart
Storage.manager.register('dropbox', DropboxDriver());
await Storage().disk('dropbox').put('notes/a.txt', 'hello', exact: true);
```

## Errors

All errors extend `StorageException` and have the `key`:

| Error | When |
| --- | --- |
| `FileNotFoundException` | the file does not exist |
| `PermissionDeniedException` | a file system permission error, or S3 403 |
| `InvalidKeyException` | an unsafe key |
| `UnsupportedOperationException` | the driver cannot do this |
| `DriverException` | any other error. The first error is in `cause` |

A key with `..`, an absolute path like `/etc/passwd`, or a null byte throws `InvalidKeyException`. So a user cannot get files outside the disk.

## Testing

To replace a disk with a memory disk in tests, see [Testing](testing.md#test-file-storage). A disk also has `assertExists` and `assertMissing`. They throw a StateError when the check fails:

```dart
Disk fake = Storage.manager.fake('s3');
await fake.assertExists('avatars/1.png');
await fake.assertMissing('avatars/old.png');
```

`Storage.manager.restore('s3')` removes one fake, and `Storage.manager.restoreAll()` removes all fakes.

## Without Dox

`dox_storage` also works on its own:

```bash
dart pub add dox_storage
```

Make a `DriveManager` with your disks:

```dart
import 'dart:io';

import 'package:dox_storage/dox_storage.dart';

Map<String, String> env = Platform.environment;

DriveManager drive = DriveManager(
  defaultDisk: 'local',
  disks: <String, DriverContract>{
    'local': LocalDriver(LocalDriverConfig(
      root: 'storage',
      urlBase: 'https://app.test/uploads',
      atomicWrites: true, // off by default
      appKey: env['APP_KEY'], // signs local URLs
    )),
    's3': S3Driver(S3DriverConfig(
      bucket: 'my-bucket',
      region: 'us-east-1',
      accessKeyId: env['AWS_ACCESS_KEY_ID']!,
      secretAccessKey: env['AWS_SECRET_ACCESS_KEY']!,
    )),
  },
);

Disk disk = drive.use('s3'); // or drive.use() for the default disk
```

To add your own driver, call `drive.register('dropbox', DropboxDriver())`. For file modes, give `LocalDriverConfig(permissions: LocalPermissions())`.

### Checking a local signed URL

Check a local signed URL in the route that serves the file:

```dart
LocalDriver local = LocalDriver(localConfig);
bool ok = local.verifySignedUrl(keyFromPath, req.uri.queryParameters);
if (!ok) {
  return response('Forbidden').statusCode(403);
}
```

## Next steps

- [File upload](../guides/file-upload.md): a full upload route, from the DTO to the URL.
- [Request](../the-basic/request.md): read an uploaded file.
- [Static files and SPA](../guides/static-files.md): serve a folder.

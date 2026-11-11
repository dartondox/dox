---
icon: lucide/hard-drive
---

# Storage

This page shows how to save and read files with `dox_storage`.

`dox_storage` gives one API for files in many places: local disk, AWS S3 and S3-compatible services.

## In a Dox app

A new app from `dox create` already has steps 1 to 3. Go to step 4.

### 1. Install

```bash
dart pub add dox_storage
```

### 2. The config

```dart title="lib/config/storage.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/env.dart';

StorageConfig storageConfig = StorageConfig(
  defaultDisk: env.storageDisk, // STORAGE_DISK in .env, default 'local'
  disks: <String, Map<String, dynamic>>{
    'local': <String, dynamic>{'driver': 'local', 'root': 'storage'},
  },
);
```

### 3. The provider

The provider sets up the disks in every isolate. Put it in `lib/providers/`, so the generated container finds it:

```dart title="lib/providers/storage_provider.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/storage.dart';

class AppStorageProvider extends StorageProvider {
  AppStorageProvider() : super(storageConfig);
}
```

Run `dart run build_runner build`.

### 4. Use it

```dart
import 'package:dox_storage/dox_storage.dart';

Route.post('/avatar', (DoxRequest req) async {
  RequestFile file = req.input('avatar');
  String path = await Storage().putFile('avatars', file);
  return <String, String>{'path': path}; // /avatars/<uuid>.png
});
```

- `Storage().use('s3')` gives the full `Disk` of this page.
- `Storage.route('files')` serves local signed URLs.
- S3 disks, env keys and all `Storage()` functions are in [File Storage](../digging-deeper/file-storage.md).

## Drivers

| Driver | Use for | Signed download URL | Signed upload URL |
| --- | --- | --- | --- |
| `LocalDriver` | a folder on the server | Yes (HMAC with your app key) | No |
| `S3Driver` | AWS S3, Cloudflare R2, MinIO, DigitalOcean Spaces, GCS (HMAC keys) | Yes (SigV4) | Yes (SigV4) |
| `MemoryDriver` | tests | fake URLs | fake URLs |

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

`use()` throws `UnsupportedOperationException` when no disk has that name.

`LocalDriverConfig(atomicWrites: true)` makes a local disk write to a temp file and rename it when the write is done.
In a Dox app, use `'atomic_writes': true` in the disk map.
A failed or stopped upload then never leaves a partial file, and the old file stays. Temp file names end with `.dox-upload.tmp`, and `listAll()` hides them.
It is off by default.

`LocalDriverConfig(permissions: LocalPermissions())` makes visibility the file mode, like Laravel.
In a Dox app, use `'permissions': true` in the disk map.
`setVisibility` then runs `chmod` and `getVisibility` reads the mode of the file.
The modes are public file `0644`, private file `0600`, public folder `0755` and private folder `0700`.
`LocalPermissions` takes other modes. In a Dox app, the map has a `file` and a `dir` key, each with `public` and `private`. A key that is not one of these is ignored.
Each mode must be an int from 0 to 0o777. A string like `'0644'`, a negative number or a bigger number throws `ArgumentError` when the disk is made.
It is off by default. On Windows it does nothing.

- The mode is set before the content is written. A private file is never readable by others, not even for a moment.
- A new file gets the visibility of the write, or the disk `visibility`.
- An overwrite, `append` and `prepend` keep the mode the file has, unless the call gives a visibility.
- A `copy` gets the visibility of the call, or else the mode of the source. It is written to a temp file first and then renamed. Listings hide that temp file. A copy onto a symlink replaces the link.
- A `move` keeps the mode, unless the call gives a visibility.
- Folders that a write creates get the folder mode. Folders that were there before, and the disk root, keep their mode.
- `getVisibility` reads the real mode. The private mode is private. Any other mode is public.
- `getVisibility` and `setVisibility` of a symlink throw `UnsupportedOperationException`.
- When the `chmod` fails, a file that the write created is removed.

On every local disk, with `permissions` on or off, `copy` or `move` of a missing file throws `FileNotFoundException` and makes no folders.

## Use a disk

In a Dox app, get a disk with `Storage().use('s3')`. Without Dox, use `drive.use('s3')`.

```dart
await disk.put('avatars/1.png', bytes); // String, List<int> or Stream<List<int>>
await disk.put('a.json', '{}', options: WriteOptions(contentType: 'application/json', visibility: Visibility.public));
await disk.putStream('videos/big.mp4', File('big.mp4').openRead());

Uint8List data = await disk.get('avatars/1.png');
String text = await disk.getString('notes/a.txt');
Stream<List<int>> stream = await disk.getStream('videos/big.mp4');
ObjectMetaData meta = await disk.getMetaData('avatars/1.png'); // size, contentType, lastModified, etag
bool found = await disk.exists('avatars/1.png');
int size = await disk.size('avatars/1.png');
DateTime changed = await disk.lastModified('avatars/1.png');

await disk.append('logs/app.log', 'new line');  // a missing file is made
await disk.prepend('logs/app.log', 'first line');
await disk.makeDirectory('reports/2026');        // local disk only
bool folder = await disk.directoryExists('reports');

await disk.copy('a.png', 'b.png');
await disk.move('b.png', 'c.png');
await disk.delete('c.png');
bool gone = await disk.missing('c.png');
await disk.deleteAll('avatars'); // every file under this prefix, '' for all
await disk.deleteDirectory('reports'); // never the root

List<String> files = await disk.files('avatars');         // direct files
List<String> all = await disk.allFiles('avatars');        // in sub-folders too
List<String> folders = await disk.directories('avatars'); // direct sub-folders

ListResult page = await disk.listAll('avatars', ListOptions(recursive: true, limit: 100));
// next page: ListOptions(paginationToken: page.paginationToken)

await disk.setVisibility('avatars/1.png', Visibility.public);
Visibility v = await disk.getVisibility('avatars/1.png');
```

- `size` and `lastModified` throw `FileNotFoundException` when the file is missing.
- `append` and `prepend` put a `\n` between the old and the new text, but only when the file is not empty. Change it with `separator`, like `separator: ', '`.
- `append` and `prepend` keep the visibility and content type of the file.
- `append` and `prepend` read the file and write it back. They are not atomic, so two writers at the same time can lose a write.
- `makeDirectory` makes the folder and its parent folders on a local disk. On any other disk it does nothing, because those disks have no real folders.
- `files`, `allFiles` and `directories` give keys, like `avatars/1.png`. They read every page of `listAll`.
- `deleteDirectory` deletes a folder and its files. The root (`''` or `/`) throws `InvalidKeyException`. `deleteAll()` empties the whole disk.
- `directoryExists` is true when a folder exists. On a local disk it checks the real folder. On S3 and memory disks, a folder exists when a file is under it. `exists` is true for files only.

### Save an upload

Stream the upload to the disk. The file is not loaded into memory.

```dart
Route.post('/avatar', (DoxRequest req) async {
  RequestFile file = req.input('avatar');
  String key = 'avatars/${DateTime.now().microsecondsSinceEpoch}.${file.extension}';
  await disk.putStream(key, file.stream());
  return <String, String>{'url': await disk.getUrl(key)};
});
```

!!! warning
    Do not use `file.filename` from the client as the key. A client can send any name.
    Make your own name, like above or with a uuid.

## URLs and signed URLs

```dart
String url = await disk.getUrl('avatars/1.png');

// a download link that works for 10 minutes
String signed = await disk.getSignedUrl('avatars/1.png',
    options: SignedUrlOptions(expiresIn: Duration(minutes: 10)));

// the browser can upload straight to S3 with this URL
String upload = await disk.getSignedUploadUrl('avatars/2.png',
    options: SignedUrlOptions(contentType: 'image/png'));
```

- `expiresIn` is 30 minutes when you do not set it.
- S3 signed URLs can live at most 7 days. This is an S3 rule.
- `contentDisposition` asks the server to send this header on download, like `attachment; filename="report.pdf"`.
- Set `urlBase` to serve public files from a CDN.

### Check a local signed URL

In a Dox app, `Storage.route('files')` does this for you.

`LocalDriver.getSignedUrl` returns `<urlBase>/<key>?expires=...&signature=...`.
Check it in the route that serves the file:

```dart
LocalDriver local = LocalDriver(localConfig);
bool ok = local.verifySignedUrl(keyFromPath, req.uri.queryParameters);
if (!ok) {
  return response('Forbidden').statusCode(403);
}
```

## S3-compatible services

### Cloudflare R2

Set `supportsAcl: false`. R2 does not take ACL headers.

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

MinIO needs path style URLs, so set `forcePathStyle: true`.

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

Spaces works like S3. Put the region of your space in `region` and in the endpoint.

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

Set `supportsAcl: false` and `supportsBatchDelete: false`. GCS does not take ACL headers or the S3 batch delete call.

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

!!! info "Big files"
    - `put` sends one request. S3 allows at most 5 GiB in one request.
    - `putStream` uses a multipart upload when the stream is bigger than `multipartPartSize` (8 MiB).
      Only one part is in memory at a time. The limit is about 78 GiB. Raise `multipartPartSize` for bigger files.
    - `copy` and `move` copy on the server. S3 allows at most 5 GiB here.

## Keys are checked

- `a//b/./c.txt` becomes `a/b/c.txt`. `\` becomes `/`.
- `..`, absolute paths (`/etc/passwd`) and null bytes throw `InvalidKeyException`.
- `LocalDriver` also checks that the path stays inside its root folder.

## Errors

All errors extend `StorageException` and have the `key`.

| Error | When |
| --- | --- |
| `FileNotFoundException` | the file does not exist |
| `PermissionDeniedException` | file system permission error, or S3 403 |
| `InvalidKeyException` | unsafe key |
| `UnsupportedOperationException` | the driver can not do this |
| `DriverException` | anything else. The first error is in `cause` |

## Tests

`fake()` swaps a disk for a memory disk.

```dart
Disk fake = drive.fake('s3'); // drive.use('s3') now writes to memory
await uploadAvatar();         // your code
expect(await fake.exists('avatars/1.png'), isTrue);
drive.restore('s3');
```

A disk also has `assertExists` and `assertMissing`. They throw a `StateError` when the check fails:

```dart
Disk fake = drive.fake('s3');
await uploadAvatar();
await fake.assertExists('avatars/1.png');
await fake.assertMissing('avatars/old.png');
```

## Your own driver

Implement `DriverContract` and register it.

```dart
class DropboxDriver implements DriverContract { ... }

drive.register('dropbox', DropboxDriver(...));
await drive.use('dropbox').put('a.txt', 'hello');
```

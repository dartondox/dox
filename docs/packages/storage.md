---
icon: lucide/hard-drive
---

# Storage

`dox_storage` saves and reads files with one API, on the local disk, AWS S3 and S3-compatible services.

You write the same code for every place. Only the config decides where the files go. This page shows the full API of a disk. For a shorter guide, see [File Storage](../digging-deeper/file-storage.md).

## Setup

A new app from `dox create` already has this setup. You can go to [Using a disk](#using-a-disk).

First, install the package:

```bash
dart pub add dox_storage
```

Then add the config. Each disk has a name and a driver:

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

Last, add the provider. It sets up the disks in every isolate. Put it in `lib/providers/`, so the generated container finds it:

```dart title="lib/providers/storage_provider.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/storage.dart';

class AppStorageProvider extends StorageProvider {
  AppStorageProvider() : super(storageConfig);
}
```

Then run `dart run build_runner build`.

S3 disks and their env keys are in [File Storage](../digging-deeper/file-storage.md).

### Drivers

| Driver | Use for | Signed download URL | Signed upload URL |
| --- | --- | --- | --- |
| `local` | a folder on the server | Yes (HMAC with your app key) | No |
| `s3` | AWS S3, Cloudflare R2, MinIO, DigitalOcean Spaces, GCS (HMAC keys) | Yes (SigV4) | Yes (SigV4) |
| `memory` | tests | fake URLs | fake URLs |

## Using a disk

`Storage()` has short functions for common work. For example, `putFile` saves an upload with a new random name:

```dart
Route.post('/avatar', (DoxRequest req) async {
  RequestFile file = req.input('avatar');
  String path = await Storage().putFile('avatars', file);
  return <String, String>{'path': path}; // /avatars/<uuid>.png
});
```

For the full API, get a `Disk` with `use`. With no name, you get the default disk:

```dart
Disk disk = Storage().use('s3');
```

The rest of this page shows the methods of a `Disk`.

## Storing files

The `put` method stores a `String`, a `List<int>` or a `Stream<List<int>>`:

```dart
await disk.put('avatars/1.png', bytes);
```

You can set the content type and the visibility with `WriteOptions`:

```dart
await disk.put('a.json', '{}', options: WriteOptions(contentType: 'application/json', visibility: Visibility.public));
```

### Storing big files

`putStream` writes a stream, so the file is not loaded into memory:

```dart
await disk.putStream('videos/big.mp4', File('big.mp4').openRead());
```

### Saving an upload

Stream the upload to the disk, so the file is not loaded into memory:

```dart
Route.post('/avatar', (DoxRequest req) async {
  RequestFile file = req.input('avatar');
  String key = 'avatars/${DateTime.now().microsecondsSinceEpoch}.${file.extension}';
  await disk.putStream(key, file.stream());
  return <String, String>{'url': await disk.getUrl(key)};
});
```

Do not use `file.filename` from the client as the key, because a client can send any name. Make your own name, like above or with a uuid.

### Adding to a file

`append` adds text at the end of a file, and `prepend` adds it at the start. A missing file is made:

```dart
await disk.append('logs/app.log', 'new line');

await disk.prepend('logs/app.log', 'first line');
```

They put a `\n` between the old and the new text, if the file is not empty. Change it with `separator`, like `separator: ', '`. They read the file and write it back, so two writers at the same time can lose a write.

## Retrieving files

`get` reads a file as bytes, and `getString` reads it as text:

```dart
Uint8List data = await disk.get('avatars/1.png');

String text = await disk.getString('notes/a.txt');
```

For a big file, use `getStream`:

```dart
Stream<List<int>> stream = await disk.getStream('videos/big.mp4');
```

### Checking if a file exists

`exists` returns `true` when the file is there. `missing` is the opposite:

```dart
bool found = await disk.exists('avatars/1.png');

bool gone = await disk.missing('c.png');
```

### File metadata

`getMetaData` gives the size, content type, last change time and etag in one call. `size` and `lastModified` give one value each:

```dart
ObjectMetaData meta = await disk.getMetaData('avatars/1.png');

int size = await disk.size('avatars/1.png');

DateTime changed = await disk.lastModified('avatars/1.png');
```

`size` and `lastModified` throw `FileNotFoundException` when the file is missing.

## Copying and moving files

```dart
await disk.copy('a.png', 'b.png');

await disk.move('b.png', 'c.png');
```

On S3, `copy` and `move` copy on the server, so the file does not pass through your app.

## Deleting files

`delete` removes one file. `deleteAll` removes every file under a prefix:

```dart
await disk.delete('c.png');

await disk.deleteAll('avatars'); // '' or no argument for the whole disk
```

## Directories

`files` gives the files directly in a folder, and `allFiles` also gives the files in sub folders. `directories` gives the direct sub folders. They return keys, like `avatars/1.png`:

```dart
List<String> files = await disk.files('avatars');

List<String> all = await disk.allFiles('avatars');

List<String> folders = await disk.directories('avatars');
```

`deleteDirectory` deletes a folder and its files. It never deletes the root, so `''` or `/` throws `InvalidKeyException`:

```dart
await disk.deleteDirectory('reports');
```

`makeDirectory` makes a folder and its parents on a local disk. On other disks it does nothing, because they have no real folders. `directoryExists` checks a folder. On S3 and memory disks, a folder exists when a file is under it:

```dart
await disk.makeDirectory('reports/2026');

bool folder = await disk.directoryExists('reports');
```

### Listing page by page

For a big folder, read it one page at a time with `listAll`:

```dart
ListResult page = await disk.listAll('avatars', ListOptions(recursive: true, limit: 100));
// next page: ListOptions(paginationToken: page.paginationToken)
```

## File visibility

A file is `public` or `private`. Set it with `setVisibility`, and read it with `getVisibility`:

```dart
await disk.setVisibility('avatars/1.png', Visibility.public);

Visibility v = await disk.getVisibility('avatars/1.png');
```

On a local disk, visibility does nothing by default. To make it set real file modes, turn on [file permissions](#local-file-permissions).

## URLs

`getUrl` gives the address of a file. Set `url` on the disk to serve public files from a CDN:

```dart
String url = await disk.getUrl('avatars/1.png');
```

### Signed URLs

A signed URL works only for a short time, so you can share a private file. `expiresIn` is 30 minutes when you do not set it:

```dart
String signed = await disk.getSignedUrl('avatars/1.png',
    options: SignedUrlOptions(expiresIn: Duration(minutes: 10)));
```

`contentDisposition` asks the server to send this header on download, like `attachment; filename="report.pdf"`. On S3, a signed URL can live at most 7 days.

On a local disk, the app serves the file itself. `Storage.route('files')` adds a route that checks the signature and serves the file.

### Signed upload URLs

On S3, the browser can upload a file straight to the bucket with a signed upload URL. So the file does not pass through your app:

```dart
String upload = await disk.getSignedUploadUrl('avatars/2.png',
    options: SignedUrlOptions(contentType: 'image/png'));
```

## Local disk options

### Atomic writes

Sometimes an upload fails or stops in the middle. Turn on `atomic_writes` so this never leaves a half written file. The disk then writes to a temp file and renames it when the write is done, so the old file stays until then:

```dart
'local': <String, dynamic>{'driver': 'local', 'root': 'storage', 'atomic_writes': true},
```

It is off by default.

### Local file permissions

Turn on `permissions` if you want visibility to set the real file mode. Then `setVisibility` runs `chmod` and `getVisibility` reads the mode:

```dart
'local': <String, dynamic>{'driver': 'local', 'root': 'storage', 'permissions': true},
```

The modes are `0644` for a public file, `0600` for a private file, `0755` for a public folder and `0700` for a private folder. To use other modes, give a map instead of `true`:

```dart
'permissions': <String, dynamic>{
  'file': <String, int>{'public': 0x1a4, 'private': 0x180},
  'dir': <String, int>{'public': 0x1ed, 'private': 0x1c0},
},
```

A mode that is not in the map keeps its default. Each mode must be an int from 0 to 0x1ff (0777). It is off by default, and it does nothing on Windows.

## S3-compatible services

The examples use `S3DriverConfig`, the class behind an `s3` disk. In a Dox config, the same settings are keys in the disk map. See [File Storage](../digging-deeper/file-storage.md).

### Cloudflare R2

Set `supportsAcl: false`, because R2 does not take ACL headers:

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

MinIO needs path style URLs, so set `forcePathStyle: true`:

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

Spaces works like S3. Put the region of your space in `region` and in the endpoint:

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

Set `supportsAcl: false` and `supportsBatchDelete: false`, because GCS does not take ACL headers or the S3 batch delete call:

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

## Testing

`fake()` swaps a disk for a memory disk, so your tests write nothing to the real disk. In a Dox app, the `DriveManager` is `Storage.manager`:

```dart
Disk fake = drive.fake('s3'); // drive.use('s3') now writes to memory
await uploadAvatar();         // your code
expect(await fake.exists('avatars/1.png'), isTrue);
drive.restore('s3');
```

A disk also has `assertExists` and `assertMissing`. They throw a `StateError` when the check fails:

```dart
await fake.assertExists('avatars/1.png');

await fake.assertMissing('avatars/old.png');
```

## Errors

All errors extend `StorageException` and have the `key`.

| Error | When |
| --- | --- |
| `FileNotFoundException` | the file does not exist |
| `PermissionDeniedException` | file system permission error, or S3 403 |
| `InvalidKeyException` | unsafe key |
| `UnsupportedOperationException` | the driver can not do this |
| `DriverException` | anything else. The first error is in `cause` |

Keys are checked, so a user can not reach files outside the disk. `..`, absolute paths like `/etc/passwd` and null bytes throw `InvalidKeyException`. A local disk also checks that the path stays inside its root folder.

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

`use()` throws `UnsupportedOperationException` when no disk has that name. For file permissions, pass `LocalDriverConfig(permissions: LocalPermissions())`.

### Checking a local signed URL

A local signed URL looks like `<urlBase>/<key>?expires=...&signature=...`. Without Dox, check it in the route that serves the file:

```dart
LocalDriver local = LocalDriver(localConfig);
bool ok = local.verifySignedUrl(keyFromPath, req.uri.queryParameters);
if (!ok) {
  return response('Forbidden').statusCode(403);
}
```

### Your own driver

Implement `DriverContract` and register it:

```dart
class DropboxDriver implements DriverContract { ... }

drive.register('dropbox', DropboxDriver(...));
await drive.use('dropbox').put('a.txt', 'hello');
```

## Details

This section is for special cases. Most apps do not need it.

- Keys are cleaned: `a//b/./c.txt` becomes `a/b/c.txt`, and `\` becomes `/`.
- `append` and `prepend` keep the visibility and the content type of the file.
- On local disks, `copy` or `move` of a missing file throws `FileNotFoundException` and makes no folders.
- Atomic writes use temp files that end with `.dox-upload.tmp`. `listAll()` hides them.
- On S3, `put` sends one request, so it allows at most 5 GiB. `putStream` uses a multipart upload when the stream is bigger than `multipartPartSize` (8 MiB). Only one part is in memory at a time, and the limit is about 78 GiB. Raise `multipartPartSize` for bigger files. `copy` and `move` also allow at most 5 GiB.
- Without `permissions`, `setVisibility` on a local disk does nothing, and `getVisibility` gives the disk `visibility`.
- With `permissions`:
    - The mode is set before the content is written, so a private file is never readable by others, not even for a moment.
    - A new file gets the visibility of the write, or the disk `visibility`. An overwrite, `append`, `prepend` and `move` keep the mode of the file, unless the call gives a visibility. A `copy` gets the visibility of the call, or the mode of the source.
    - Folders that a write creates get the folder mode. Folders that were there before, and the disk root, keep their mode.
    - `getVisibility` reads the real mode: the private mode is private, any other mode is public.
    - `getVisibility` and `setVisibility` of a symlink throw `UnsupportedOperationException`. A copy onto a symlink replaces the link.
    - When `chmod` fails, a file that the write created is removed.
    - A mode that is not an int, like `'0644'`, or is out of range throws `ArgumentError` when the disk is made. A key in the map that is not `file`, `dir`, `public` or `private` is ignored.

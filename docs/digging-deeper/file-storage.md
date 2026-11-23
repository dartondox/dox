---
icon: lucide/hard-drive
---

# File Storage

`Storage()` saves and reads files on a disk: a local folder, AWS S3 (and R2, MinIO, Spaces), or memory.

You use the same methods for every disk. So you can keep files in a local folder in development and on S3 in production, and your code stays the same.

It is in the `dox_storage` package. A new project already has it. You can also use the package [without Dox](#without-dox).

```dart
import 'package:dox_storage/dox_storage.dart';

Route.post('/avatar', (DoxRequest req) async {
  RequestFile file = req.input('avatar');
  String path = await Storage().putFile('avatars', file);
  return <String, String>{'path': path}; // /avatars/<uuid>.png
});
```

## Setup

If your project does not have storage yet, add it with the CLI:

```bash
dox add storage
```

It writes `lib/config/storage.dart`, the provider, the `storage` folder and the `STORAGE_DISK=local` key. It never overwrites a file, so it is safe to run twice.

Add `--disk=s3` to also add an `s3` disk and the `AWS_*` keys. `STORAGE_DISK` stays `local`, so the app starts before you fill in the keys. Fill them in, then set `STORAGE_DISK=s3`.

### Configuration

The disks are in `lib/config/storage.dart`. A new project has one `local` disk in the `storage` folder. `STORAGE_DISK` in `.env` picks the default disk.

To add disks, edit the file. This example adds a `url` to the local disk, an `s3` disk and a `memory` disk:

```dart title="lib/config/storage.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/env.dart';

StorageConfig storageConfig = StorageConfig(
  defaultDisk: env.storageDisk,
  disks: <String, Map<String, dynamic>>{
    'local': <String, dynamic>{
      'driver': 'local',
      'root': 'storage',
      'url': 'https://app.test/files', // for signedUrl(); url() gives /storage/<path> without it
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

Each driver takes these options:

| Driver | Options |
| --- | --- |
| `local` | `root` (default `storage`), `url`, `app_key` (default: your APP_KEY), `visibility`, `atomic_writes`, `permissions` |
| `s3` | `bucket`, `region`, `key`, `secret`, `token`, `endpoint`, `path_style` (MinIO), `url` (CDN), `visibility`, `acl`, `batch_delete`, `unsigned_payload` |
| `memory` | none. For tests |

The provider of a new project sets up these disks in every isolate. It is in `lib/providers/`, so the generated container finds it:

```dart title="lib/providers/storage_provider.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/storage.dart';

class AppStorageProvider extends StorageProvider {
  AppStorageProvider() : super(storageConfig);
}
```

### Drivers

| Driver | Use for | Signed download URL | Signed upload URL |
| --- | --- | --- | --- |
| `local` | a folder on the server | Yes (HMAC with your app key) | No |
| `s3` | AWS S3, Cloudflare R2, MinIO, DigitalOcean Spaces, GCS (HMAC keys) | Yes (SigV4) | Yes (SigV4) |
| `memory` | tests | fake URLs | fake URLs |

### The S3 disk

The `s3` disk reads five keys that a new project does not have yet. Add them to `lib/config/env.dart` and run `dart run build_runner build`. They are nullable, and the `s3` disk is only added when `AWS_BUCKET` is set, so the app starts without them:

```dart title="lib/config/env.dart"
  String? get awsBucket;

  String get awsDefaultRegion => 'us-east-1';

  String? get awsAccessKeyId;

  String? get awsSecretAccessKey;

  /// R2, MinIO or Spaces. Null for AWS.
  String? get awsEndpoint;
```

The `s3` disk needs `bucket`, `key` and `secret`. If one is missing, the app stops at start with an `ArgumentError` that names the setting.

### Skipping the body hash

To save CPU on big uploads, add `unsigned_payload` to the `s3` disk. The upload then skips the hash of the body. Only use it over HTTPS:

```dart
's3': <String, dynamic>{
  'driver': 's3',
  'bucket': env.awsBucket,
  // ... region, key, secret, endpoint
  'unsigned_payload': true,
},
```

## Using another disk

`Storage()` uses the default disk. Use `disk` to pick another one:

```dart
await Storage().disk('s3').put('reports/2026.pdf', bytes, exact: true);
```

## Storing files

The `putFile` method saves a file in a folder with a new uuid name, and returns the path. It takes a `RequestFile` or bytes. For bytes, Dox finds the extension from the bytes, or you pass `extension:`:

```dart
// save with a new uuid file name, returns '/images/<uuid>.png'
String path = await Storage().putFile('images', file);  // a RequestFile
Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
String path2 = await Storage().putFile('images', bytes, extension: 'png');
String path3 = await Storage().put('images', bytes, extension: 'png'); // like putFile
```

### Storing with your own name

If you want to pick the file name, use `putFileAs`. It replaces an old file with the same name:

```dart
String path4 = await Storage().putFileAs('avatars', file, 'user-1.png'); // your own name
```

Do not use the file name from the client here, because the name is used as it is. Make your own name, like `user-1.png`.

### Storing at an exact path

Use `put` with `exact: true` to write to an exact path. It replaces an old file there and returns the path. It takes a `String`, a `List<int>` or a `Stream<List<int>>`:

```dart
// save to this exact path. String, List<int> or Stream<List<int>>
await Storage().put('notes/a.txt', 'hello', exact: true);
```

### Storing uploaded files

An uploaded file can store itself. `store` gives it a new uuid name, like `putFile`. `storeAs` uses your name, like `putFileAs`. Both take `disk:`:

```dart
RequestFile file = req.input('image');
String path = await file.store('images');
String onS3 = await file.store('images', disk: 's3');
String avatar = await file.storeAs('avatars', 'user-1.png');
```

`putFile` and `store` take the extension from the file name. But if the bytes are a known format (png, jpg, pdf, zip, ...) that does not match the name, the extension of the bytes is used. So a png sent as `a.html` is saved as `.png`, and it is never served as a web page.

### Prepending and appending

Use `append` and `prepend` to add text to the end or the start of a file. A missing file is made:

```dart
await Storage().append('logs/app.log', 'new line');    // a missing file is made
await Storage().prepend('logs/app.log', 'first line');
```

They add a new line between the old and the new text, if the file is not empty. Change it with `separator`.

## Retrieving files

The `get` method returns the bytes of a file, or `null` when the file is missing:

```dart
Uint8List? found = await Storage().get(path);  // null when missing
```

### Checking if a file exists

`exists` checks for a file. `missing` is the opposite:

```dart
bool exists = await Storage().exists(path);           // files only
bool gone = await Storage().missing(path);            // not exists()
```

### File metadata

`size` gives the size in bytes, and `lastModified` gives the time of the last change. Both throw `FileNotFoundException` when the file is missing:

```dart
int size = await Storage().size(path);                 // throws when missing
DateTime changed = await Storage().lastModified(path); // throws when missing
```

## Downloading files

Sometimes you want to send a stored file to the browser. `stream` shows it in the browser, and `download` makes the browser save it as a file:

```dart
Route.get('/photo', (DoxRequest req) {
  return Storage().stream(req.input('path'));    // shown in the browser
});

Route.get('/report', (DoxRequest req) {
  return Storage().disk('s3').download('reports/2024.pdf'); // saved as a file
});
```

Both read the file as a stream, so a big file is never loaded into memory. A missing file answers `404`.

`download` names the file after the last part of the path. Pass `name:` to pick another name:

```dart
Route.get('/invoice', (DoxRequest req) {
  return Storage().download('invoices/42.pdf', name: 'Invoice 42.pdf');
});
```

If you want to add headers, put the download in a `response()`:

```dart
Route.get('/invoice', (DoxRequest req) async {
  DownloadableFile file = await Storage().download('invoices/42.pdf');
  return response(file).header('Cache-Control', 'no-store');
});
```

## File URLs

The `url` method gives the URL of a file. On a local disk with no `url` option, it gives `/storage/<path>`:

```dart
String url = await Storage().url(path);         // /storage/<path> when the disk has no `url`
```

Dox only serves that URL when you add `Storage.route('storage', signed: false)`. See [Serving local files](#serving-local-files).

### Signed URLs

Sometimes a file should only be open for a short time, like a private invoice. Use `signedUrl` for this. `temporaryUrl` is the same method:

```dart
String signed = await Storage().signedUrl(path, expiresIn: Duration(minutes: 10));
String same = await Storage().temporaryUrl(path); // the same as signedUrl()
```

On a local disk, `signedUrl` needs the disk `url` option. Set it to the full URL of the route, like `https://app.test/files`.

### Serving local files

A local disk needs a route, so the browser can open its files. `Storage.route` adds one:

```dart
// lib/routes/web.dart
Storage.route('files');                    // GET /files/{key*}, signed URLs only
Storage.route('public', signed: false);    // any file of the disk
Storage.route('docs', disk: 'memory', signed: false); // another disk than the default
Storage.route('uploads', download: true);  // every file is a download
```

With a signed route, the URL looks like this:

```dart
String url = await Storage().signedUrl('invoices/1.pdf'); // https://app.test/files/invoices/1.pdf?expires=...&signature=...
```

- A missing, wrong or expired signature answers `403`.
- Signed URLs work only on a `local` disk, and only on the route of their own disk. For another disk, use `signed: false`.
- An html, svg, xml or javascript file is always sent as a download in a sandbox, so its script does not run on your site.
- Every file has `X-Content-Type-Options: nosniff`.

## Copying and moving files

`copy` and `move` replace an old file at the new path:

```dart
await Storage().copy('notes/a.txt', 'backup/a.txt');
await Storage().move('backup/a.txt', 'old/a.txt');
```

On S3 the copy runs inside S3, so the bytes do not pass through your app. A missing source file answers `404`.

## Deleting files

```dart
await Storage().delete(path);
```

## Directories

`files` gives the files in a folder. `allFiles` also gives the files in sub-folders. `directories` gives the sub-folders. All paths start with `/`, like the paths from `putFile`:

```dart
List<String> files = await Storage().files('images');         // direct files only
List<String> all = await Storage().allFiles('images');        // in sub-folders too
List<String> folders = await Storage().directories('images'); // direct sub-folders
```

Use `directoryExists` to check for a folder. On S3 and memory disks, a folder exists when a file is under it:

```dart
bool folder = await Storage().directoryExists('images');
```

`makeDirectory` makes a folder. It only works on a local disk. On other disks it does nothing:

```dart
await Storage().makeDirectory('reports');              // local disk only
```

`deleteDirectory` deletes a folder and every file in it. A missing folder is not an error:

```dart
await Storage().deleteDirectory('old');                       // the folder and its files
```

It refuses the root (`''` or `/`) with `InvalidKeyException`, so a wrong path can not empty the disk. To empty a whole disk on purpose, use `Storage().use().deleteAll()`.

## File visibility

A file can be `public` or `private`. Use `setVisibility` and `getVisibility`:

```dart
await Storage().setVisibility(path, Visibility.private);
Visibility visibility = await Storage().getVisibility(path);
```

- On S3, `setVisibility` sets the ACL, because `acl` is on by default. With `'acl': false` (R2 and similar), it does nothing, and `getVisibility` gives the disk `visibility`.
- On a local disk, `setVisibility` does nothing by default, and `getVisibility` gives the disk `visibility`. Turn on `permissions` to use file modes.

### Visibility on a local disk

If you want visibility to be the file mode on a local disk, add `'permissions': true` to the disk. Then `setVisibility` runs `chmod`, and `getVisibility` reads the mode of the file:

```dart
'local': <String, dynamic>{'driver': 'local', 'root': 'storage', 'permissions': true},
```

The modes are: public file `0644`, private file `0600`, public folder `0755`, private folder `0700`. To change them, see [Custom file modes](#custom-file-modes). On Windows, `permissions` does nothing, because there is no `chmod`.

## The disk API

`Storage()` has short methods for common work. For more control, get a `Disk` with `use`. With no name, you get the default disk:

```dart
Disk disk = Storage().use('s3');
```

### Write options

The `put` method of a `Disk` writes to the exact key. You can set the content type and the visibility with `WriteOptions`:

```dart
await disk.put('a.json', '{}', options: WriteOptions(contentType: 'application/json', visibility: Visibility.public));
```

### Storing big files

`putStream` writes a stream, so the file is not loaded into memory:

```dart
await disk.putStream('videos/big.mp4', File('big.mp4').openRead());
```

### Reading text and streams

`getString` reads a file as text. For a big file, use `getStream`. Both throw `FileNotFoundException` when the file is missing:

```dart
String text = await disk.getString('notes/a.txt');

Stream<List<int>> stream = await disk.getStream('videos/big.mp4');
```

### All metadata in one call

`getMetaData` gives the size, content type, last change time and etag:

```dart
ObjectMetaData meta = await disk.getMetaData('avatars/1.png');
```

### Deleting many files

`deleteAll` removes every file under a prefix. With `''` or no argument, it empties the disk:

```dart
await disk.deleteAll('avatars');
```

### Listing page by page

For a big folder, read it one page at a time with `listAll`:

```dart
ListResult page = await disk.listAll('avatars', ListOptions(recursive: true, limit: 100));
// next page: ListOptions(paginationToken: page.paginationToken)
```

### Signed URL options

`getSignedUrl` takes `SignedUrlOptions`. `expiresIn` is 30 minutes when you do not set it. `contentDisposition` asks the server to send this header on download, like `attachment; filename="report.pdf"`. On S3, a signed URL can live 7 days at most:

```dart
String signed = await disk.getSignedUrl('avatars/1.png',
    options: SignedUrlOptions(expiresIn: Duration(minutes: 10)));
```

### Signed upload URLs

On S3, the browser can upload a file straight to the bucket with a signed upload URL. So the file does not pass through your app:

```dart
String upload = await disk.getSignedUploadUrl('avatars/2.png',
    options: SignedUrlOptions(contentType: 'image/png'));
```

## S3-compatible services

The examples use `S3DriverConfig`, the class behind an `s3` disk. In a Dox config, the same settings are keys in the disk map: `endpoint`, `path_style`, `acl` and `batch_delete`. See [Configuration](#configuration).

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

## Custom drivers

Implement `DriverContract` from `package:dox_storage/dox_storage.dart`. Register it in a [provider](providers.md), so every isolate has it:

```dart
Storage.manager.register('dropbox', DropboxDriver());
await Storage().disk('dropbox').put('notes/a.txt', 'hello', exact: true);
```

## Testing

To swap a disk with a memory disk in tests, see [Testing](testing.md#test-file-storage).

`Storage.manager.restoreAll()` removes all fakes in one call.

A disk also has `assertExists` and `assertMissing`. They throw a `StateError` when the check fails:

```dart
Disk fake = Storage.manager.fake('s3');
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

To add your own driver, call `drive.register('dropbox', DropboxDriver())`. `use()` throws `UnsupportedOperationException` when no disk has that name. For file permissions, pass `LocalDriverConfig(permissions: LocalPermissions())`.

### Checking a local signed URL

A local signed URL looks like `<urlBase>/<key>?expires=...&signature=...`. Without Dox, check it in the route that serves the file:

```dart
LocalDriver local = LocalDriver(localConfig);
bool ok = local.verifySignedUrl(keyFromPath, req.uri.queryParameters);
if (!ok) {
  return response('Forbidden').statusCode(403);
}
```

## Details

This section is for special cases. Most apps do not need it.

### Signature and the body

`unsigned_payload` is off by default. The signature then does not cover the body, so only use it over HTTPS.

### S3 part size

`multipartPartSize` is the size of one part of a big upload. It is a field of `S3DriverConfig`, not a key of the disk map. The default is 8 MiB. S3 needs 5 MiB to 5 GiB. With another size, Dox prints one warning to stderr. It does not throw.

### Atomic writes

A local disk writes a file in place by default. Add `'atomic_writes': true` to write to a temp file and rename it when the write is done. Then a failed upload never leaves a partial file, and the old file stays:

```dart
'local': <String, dynamic>{'driver': 'local', 'root': 'storage', 'atomic_writes': true},
```

The rename makes a new file. So the folder must be writable, the file gets the default mode and owner, a hard link keeps the old content, and a symlink is replaced.

### Custom file modes

Give `permissions` a map with a `file` and a `dir` key. Each has a `public` and a `private` mode. A mode you leave out keeps its default. Dart has no octal numbers, so write the modes in hex: `0x1a0` is `0640`, `0x1e8` is `0750`:

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

Each mode must be an int from 0 to 0x1ff (0777). Anything else, like the string `'0644'`, throws `ArgumentError` when the disk is made. Other keys are ignored.

### How file modes work

- The mode is set before the content is written, so a private file is never readable by others, not even for a moment.
- A new file gets the visibility of the write, or the disk `visibility`.
- An overwrite, `append`, `prepend` and `move` keep the mode of the file, unless the call gives a visibility.
- A `copy` gets the visibility of the call, or else the mode of the source.
- Folders that a write creates get the folder mode. Folders that were there before, and the disk root, keep their mode.
- `getVisibility` reads the real mode. The private mode is private. Any other mode is public.
- `getVisibility` and `setVisibility` of a symlink throw `UnsupportedOperationException`.
- If the `chmod` fails, a file that the write created is removed.

### Other cases

- `append` and `prepend` read the file and write it back, so two writers at the same time can lose a write. They keep the visibility and content type of the file.
- `putFile` with a `RequestFile` on a local disk moves the upload temp file, so it does not read the file into memory.
- `directoryExists('')` is always true: the empty path is the root.
- `getVisibility` and `setVisibility` of a missing file answer `404`. With `'acl': false` on S3, `getVisibility` gives the disk `visibility`, also for a missing file.
- On a local disk, a `copy` or `move` of a missing file makes no folders. A local `copy` writes a temp file and renames it. Listings hide that temp file.
- Any `download` name is safe in the header. Quotes are escaped, a new line becomes `_`, and a name like `résumé.pdf` is also sent as `filename*=UTF-8''r%C3%A9sum%C3%A9.pdf`.
- Keys are cleaned: `a//b/./c.txt` becomes `a/b/c.txt`, and `\` becomes `/`.
- Atomic writes use temp files that end with `.dox-upload.tmp`. `listAll()` hides them.
- On S3, `put` sends one request, so the limit is 5 GiB. `putStream` uses a multipart upload when the stream is bigger than `multipartPartSize`. Only one part is in memory at a time, and the limit is about 78 GiB. Raise `multipartPartSize` for bigger files. `copy` and `move` also have a limit of 5 GiB.

## See also

- [File upload](../guides/file-upload.md): a full upload route, from the DTO to the URL.
- [Request](../the-basic/request.md): read an uploaded file.
- [Static files and SPA](../guides/static-files.md): serve a folder.

---
icon: lucide/hard-drive
---

# File Storage

`Storage()` saves and reads files on a disk: the local folder, AWS S3 (and R2, MinIO, Spaces), or memory.

It is in the [`dox_storage`](../packages/storage.md) package. A new project already has it.

```dart
import 'package:dox_storage/dox_storage.dart';

Route.post('/avatar', (DoxRequest req) async {
  RequestFile file = req.input('avatar');
  String path = await Storage().putFile('avatars', file);
  return <String, String>{'path': path}; // /avatars/<uuid>.png
});
```

## Config

A new project already has `lib/config/storage.dart`, with one `local` disk in the `storage` folder.
`STORAGE_DISK` in `.env` picks the default disk.
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

A local disk writes a file in place by default. To write to a temp file and rename it when the write is done, add `'atomic_writes': true` to the disk. A failed or stopped upload then never leaves a partial file, and the old file stays. It is off by default.
The rename makes a new file. So the folder must be writable, the file gets the default mode and the owner of the app, a hard link keeps the old content, and a symlink is replaced.

```dart
'local': <String, dynamic>{'driver': 'local', 'root': 'storage', 'atomic_writes': true},
```

A local disk has no per-file access rules by default. `setVisibility()` does nothing there, and `getVisibility()` gives the disk `visibility`.
To make visibility the file mode, like Laravel, add `'permissions': true`. It is off by default.
Then `setVisibility()` runs `chmod` and `getVisibility()` reads the mode.
The modes are: public file `0644`, private file `0600`, public folder `0755`, private folder `0700`.
To change them, give a map with a `file` and a `dir` key. Each has a `public` and a `private` mode. A key that is not there keeps its default. A wrong key is ignored with no error.
Dart has no octal numbers, so write the modes in hex. `0x1a0` is `0640`, `0x1e8` is `0750`:

```dart
'local': <String, dynamic>{'driver': 'local', 'root': 'storage', 'permissions': true},
'private': <String, dynamic>{
  'driver': 'local',
  'root': 'storage/private',
  'visibility': 'private',
  'permissions': <String, dynamic>{
    'file': <String, int>{'public': 0x1a4, 'private': 0x1a0},
    'dir': <String, int>{'public': 0x1ed, 'private': 0x1e8},
  },
},
```

How it works:

- The mode is set before the content is written. A private file is never readable by others, not even for a moment.
- A new file gets the visibility of the write, or the disk `visibility`. An overwrite keeps the mode of the file, unless the call gives a visibility. `copy()` and `move()` also keep the mode, unless a visibility is given.
- Folders that a write creates get the folder mode. Folders that were there before, and the disk root, keep their mode.
- `getVisibility()` and `setVisibility()` of a symlink throw `UnsupportedOperationException`.
- When the `chmod` fails, a file that the write created is removed.

Windows has no `chmod`. There `permissions` does nothing.

The `s3` disk reads five keys that a new project does not have yet. Add them to
`lib/config/env.dart` and run `dart run build_runner build`. They are nullable,
and the `s3` disk is only added when `AWS_BUCKET` is set. So the app starts without them:

```dart title="lib/config/env.dart"
  String? get awsBucket;

  String get awsDefaultRegion => 'us-east-1';

  String? get awsAccessKeyId;

  String? get awsSecretAccessKey;

  /// R2, MinIO or Spaces. Null for AWS.
  String? get awsEndpoint;
```

The provider of a new project sets these disks in every isolate. It is in `lib/providers/`, so the generated container finds it:

```dart title="lib/providers/storage_provider.dart"
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/storage.dart';

class AppStorageProvider extends StorageProvider {
  AppStorageProvider() : super(storageConfig);
}
```

| Driver | Options |
| --- | --- |
| `local` | `root` (default `storage`), `url`, `app_key` (default: your APP_KEY), `visibility`, `atomic_writes`, `permissions` |
| `s3` | `bucket`, `region`, `key`, `secret`, `token`, `endpoint`, `path_style` (MinIO), `url` (CDN), `visibility`, `acl`, `batch_delete` |
| `memory` | none. For tests |

The `s3` disk needs `bucket`, `key` and `secret`. When one is missing, the app stops at start with an `ArgumentError` that names the setting.

## Functions

```dart
// save to this exact path. String, List<int> or Stream<List<int>>
await Storage().put('notes/a.txt', 'hello');

// save with a new uuid file name, returns '/images/<uuid>.png'
String path = await Storage().putFile('images', file);  // a RequestFile
Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
String path2 = await Storage().putFile('images', bytes, extension: 'png');
String path3 = await Storage().putFileAs('avatars', file, 'user-1.png'); // your own name

Uint8List? found = await Storage().get(path);  // null when missing
bool exists = await Storage().exists(path);           // files only
bool gone = await Storage().missing(path);            // not exists()
bool folder = await Storage().directoryExists('images');
await Storage().delete(path);

await Storage().copy('notes/a.txt', 'backup/a.txt');
await Storage().move('backup/a.txt', 'old/a.txt');

List<String> files = await Storage().files('images');         // direct files only
List<String> all = await Storage().allFiles('images');        // in sub-folders too
List<String> folders = await Storage().directories('images'); // direct sub-folders
await Storage().deleteDirectory('old');                       // the folder and its files

await Storage().setVisibility(path, Visibility.private);
Visibility visibility = await Storage().getVisibility(path);

int size = await Storage().size(path);                 // throws when missing
DateTime changed = await Storage().lastModified(path); // throws when missing

await Storage().append('logs/app.log', 'new line');    // a missing file is made
await Storage().prepend('logs/app.log', 'first line');
await Storage().makeDirectory('reports');              // local disk only

String url = await Storage().url(path);         // /storage/<path> when the disk has no `url`
String signed = await Storage().signedUrl(path, expiresIn: Duration(minutes: 10));
String same = await Storage().temporaryUrl(path); // the same as signedUrl()

// another disk
await Storage().disk('s3').put('reports/2026.pdf', bytes);
```

`put()` writes to the exact path, and replaces an old file there.
`putFile()` makes a new uuid name in the folder. For bytes, it finds the extension from the bytes, or you pass `extension:`.
`putFileAs()` uses your name, and replaces an old file with the same name.

`files()`, `allFiles()` and `directories()` give paths that start with `/`, like `putFile()`.
On S3 and memory disks, a folder is there when a file is under it.

`deleteDirectory()` deletes a folder and every file in it. A missing folder is not an error.
It refuses the root (`''` or `/`) with `InvalidKeyException`, so a wrong path can not empty the disk.
To empty a whole disk on purpose, use `Storage().use().deleteAll()`.

`copy()` and `move()` replace an old file at the new path. On S3 the copy runs inside S3, so the bytes do not pass through your app.
`copy()`, `move()`, `getVisibility()` and `setVisibility()` of a missing file answer `404`. On a local disk, a `copy()` or `move()` of a missing file makes no folders.

On S3, `setVisibility()` sets the ACL when `acl` is on (the default). With `'acl': false` (R2 and similar), `setVisibility()` does nothing, and `getVisibility()` gives the disk `visibility`, also for a missing file.
On a local disk, `setVisibility()` needs the `permissions` option, see [Config](#config).

On a local disk with no `url` option, `url()` gives `/storage/<path>` (no host). Dox serves it only when you add `Storage.route('storage', signed: false)`. `signedUrl()` still needs `url`.

`get()` gives `null` for a missing file, but `size()` and `lastModified()` throw `FileNotFoundException`.

`append()` and `prepend()` add a new line between the old and the new text, but only when the file is not empty. Change it with `separator`.
They keep the visibility and content type of the file.
They read the file and write it back, so two writers at the same time can lose a write.

`makeDirectory()` makes a folder only on a local disk. On any other disk it does nothing.

`exists()` finds files only. `directoryExists()` finds folders. On a local disk it checks the real folder. On S3 and memory disks, a folder exists when a file is under it.

`directoryExists('')` is always true on every disk: the empty path is the root.

`putFile` with a `RequestFile`, on the local disk, moves the upload temp file. It does not read it into memory.

An uploaded file can store itself. `store` gives it a new uuid name, like `putFile`. `storeAs` uses your name, like `putFileAs`, and replaces an old file with the same name. Both take `disk:`:

```dart
RequestFile file = req.input('image');
String path = await file.store('images');
String onS3 = await file.store('images', disk: 's3');
String avatar = await file.storeAs('avatars', 'user-1.png');
```

`storeAs` and `putFileAs` use the name as it is. Do not use the file name from the client. Make your own name, like `user-1.png`.

`putFile` and `file.store()` take the extension of an upload from the file name. When the bytes are a known format (png, jpg, pdf, zip, ...) that does not match the name, the extension of the bytes is used. So a png sent as `a.html` is saved as `.png` and is never served as a web page.

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

`download()` saves the file with the last part of the path as its name. Pass `name:` to pick the name:

```dart
Route.get('/invoice', (DoxRequest req) {
  return Storage().download('invoices/42.pdf', name: 'Invoice 42.pdf');
});
```

Any name is safe in the header. Quotes are escaped, a new line becomes `_`, and a name like `résumé.pdf` is also sent as `filename*=UTF-8''r%C3%A9sum%C3%A9.pdf`.

To add headers, put the download in a `response()`:

```dart
Route.get('/invoice', (DoxRequest req) async {
  DownloadableFile file = await Storage().download('invoices/42.pdf');
  return response(file).header('Cache-Control', 'no-store');
});
```

### Full disk API

`Storage().use('s3')` returns the `dox_storage` `Disk`: `listAll` with pages, `getMetaData`,
`putStream`, `deleteAll`, write options and more. See [dox_storage](../packages/storage.md).

## Serve local signed URLs

```dart
// lib/routes/web.dart
Storage.route('files');                    // GET /files/{key*}, signed URLs only
Storage.route('public', signed: false);    // any file of the disk
Storage.route('docs', disk: 'memory', signed: false); // another disk than the default
Storage.route('uploads', download: true);  // every file is a download
```

An html, svg, xml or javascript file is always sent as a download in a sandbox, so its script does not run on your site.
Every file has `X-Content-Type-Options: nosniff`.

```dart
String url = await Storage().signedUrl('invoices/1.pdf'); // https://app.test/files/invoices/1.pdf?expires=...&signature=...
```

A missing, wrong or expired signature answers `403`.
Signed URLs work only on a `local` disk. For another disk, use `signed: false`.
A signed URL works only on the route of its own disk.
An old signed URL, made before the disk name was part of the signature, still works on any local disk with the same app key. This ends when it expires.
Set the disk `url` option to the full URL of the route (`https://app.test/files`).

## Tests

To swap a disk with a memory disk in tests, see [Testing](testing.md#test-file-storage).

## Your own driver

Implement `DriverContract` from `package:dox_storage/dox_storage.dart`. Register it in a [provider](providers.md), so every isolate has it:

```dart
Storage.manager.register('dropbox', DropboxDriver());
await Storage().disk('dropbox').put('notes/a.txt', 'hello');
```

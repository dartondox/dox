# Storage (dox_storage)

`dox_storage` gives one API for files on many places: local disk, AWS S3 and S3-compatible services.
The API follows [FlyDrive](https://flydrive.dev) and Laravel Filesystem.

!!! tip "Which one should I use?"
    - Save uploads to the local `storage` folder: the built-in [`Storage()`](../digging-deeper/file-storage.md) in `dox_core` is enough.
    - S3, R2, MinIO, signed URLs or many disks: use `dox_storage` (this page).

## Install

```bash
dart pub add dox_storage
```

```dart
import 'package:dox_storage/dox_storage.dart';
```

## Drivers

| Driver | Use for | Signed download URL | Signed upload URL |
| --- | --- | --- | --- |
| `LocalDriver` | a folder on the server | Yes (HMAC with your app key) | No |
| `S3Driver` | AWS S3, Cloudflare R2, MinIO, DigitalOcean Spaces, GCS (HMAC keys) | Yes (SigV4) | Yes (SigV4) |
| `MemoryDriver` | tests | fake URLs | fake URLs |

## Set up the disks

```dart
DriveManager drive = DriveManager(
  defaultDisk: 'local',
  disks: <String, DriverContract>{
    'local': LocalDriver(LocalDriverConfig(
      root: 'storage',
      urlBase: 'https://app.test/uploads',
      appKey: Env.get('APP_KEY'),
    )),
    's3': S3Driver(S3DriverConfig(
      bucket: 'my-bucket',
      region: 'us-east-1',
      accessKeyId: Env.get('AWS_ACCESS_KEY_ID'),
      secretAccessKey: Env.get('AWS_SECRET_ACCESS_KEY'),
    )),
  },
);

Disk disk = drive.use('s3'); // or drive.use() for the default disk
```

## Use a disk

```dart
await disk.put('avatars/1.png', bytes); // String, List<int> or Stream<List<int>>
await disk.putStream('videos/big.mp4', File('big.mp4').openRead());

Uint8List data = await disk.get('avatars/1.png');
String text = await disk.getString('notes/a.txt');
Stream<List<int>> stream = await disk.getStream('videos/big.mp4');
ObjectMetaData meta = await disk.getMetaData('avatars/1.png'); // size, contentType, lastModified, etag
bool found = await disk.exists('avatars/1.png');

await disk.copy('a.png', 'b.png');
await disk.move('b.png', 'c.png');
await disk.delete('c.png');
await disk.deleteAll('avatars');

ListResult page = await disk.listAll('avatars', ListOptions(recursive: true, limit: 100));
await disk.setVisibility('avatars/1.png', Visibility.public);
```

### Save an upload

Stream the upload to the disk. The file is not loaded into memory.

```dart
Route.post('/avatar', (DoxRequest req) async {
  RequestFile file = req.input('avatar');
  await disk.putStream('avatars/${file.filename}', file.stream());
  return <String, String>{'url': await disk.getUrl('avatars/${file.filename}')};
});
```

!!! warning
    Do not use the file name from the client as it is. Make your own name, for example with a uuid.

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

- S3 signed URLs can live at most 7 days. This is an S3 rule.
- Set `urlBase` to serve public files from a CDN.

### Check a local signed URL

`LocalDriver.getSignedUrl` returns `<urlBase>/<key>?expires=...&signature=...`.
Check it in the route that serves the file:

```dart
bool ok = local.verifySignedUrl(keyFromPath, req.uri.queryParameters);
if (!ok) {
  return response('Forbidden').statusCode(403);
}
```

## S3-compatible services

=== "Cloudflare R2"

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

=== "MinIO"

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

=== "DigitalOcean Spaces"

    ```dart
    S3DriverConfig(
      bucket: 'my-space',
      region: 'nyc3',
      endpoint: 'https://nyc3.digitaloceanspaces.com',
      accessKeyId: '...',
      secretAccessKey: '...',
    );
    ```

=== "Google Cloud Storage"

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

## Your own driver

Implement `DriverContract` and register it.

```dart
class DropboxDriver implements DriverContract { ... }

drive.register('dropbox', DropboxDriver(...));
await drive.use('dropbox').put('a.txt', 'hello');
```

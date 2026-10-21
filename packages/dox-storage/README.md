# dox_storage

File storage for Dart and the Dox framework. One API for many places to keep
files: local disk, AWS S3, and S3-compatible services. The API follows
[FlyDrive](https://flydrive.dev) and Laravel Filesystem.

## Drivers

| Driver | Use for | Signed download URL | Signed upload URL | Visibility |
| --- | --- | --- | --- | --- |
| `LocalDriver` | A folder on the server | Yes (HMAC with your app key) | No | Fixed value from config |
| `S3Driver` | AWS S3, Cloudflare R2, MinIO, DigitalOcean Spaces, GCS (HMAC keys) | Yes (SigV4) | Yes (SigV4) | Per file ACL (when the service has ACLs) |
| `MemoryDriver` | Tests | Fake URLs | Fake URLs | Per file |

## Quick start

```dart
import 'package:dox_storage/dox_storage.dart';

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
String url = await disk.getUrl('avatars/1.png');
String signed = await disk.getSignedUrl('avatars/1.png',
    options: SignedUrlOptions(expiresIn: Duration(minutes: 10)));
String upload = await disk.getSignedUploadUrl('avatars/2.png',
    options: SignedUrlOptions(contentType: 'image/png'));
await disk.setVisibility('avatars/1.png', Visibility.public);
```

## Keys are checked

Every key goes through `KeyNormalizer`:

- `a//b/./c.txt` becomes `a/b/c.txt`, and `\` becomes `/`.
- `..` segments, absolute paths (`/etc/passwd`, `C:\x`) and null bytes throw
  `InvalidKeyException`.

`LocalDriver` also checks that the final path stays inside its root folder.

## Errors

All errors extend `StorageException` and carry the `key`.

- `FileNotFoundException`: the file does not exist.
- `PermissionDeniedException`: file system permission error or S3 403.
- `InvalidKeyException`: unsafe key.
- `UnsupportedOperationException`: the driver cannot do this.
- `DriverException`: anything else. The original error is in `cause`.

## S3 and S3-compatible services

```dart
// Cloudflare R2 (no object ACLs)
S3DriverConfig(
  bucket: 'my-bucket',
  region: 'auto',
  endpoint: 'https://<account-id>.r2.cloudflarestorage.com',
  accessKeyId: '...',
  secretAccessKey: '...',
  supportsAcl: false,
);

// MinIO
S3DriverConfig(
  bucket: 'my-bucket',
  region: 'us-east-1',
  endpoint: 'http://localhost:9000',
  forcePathStyle: true,
  accessKeyId: 'minioadmin',
  secretAccessKey: 'minioadmin',
);

// DigitalOcean Spaces
S3DriverConfig(
  bucket: 'my-space',
  region: 'nyc3',
  endpoint: 'https://nyc3.digitaloceanspaces.com',
  accessKeyId: '...',
  secretAccessKey: '...',
);

// Google Cloud Storage, XML API with HMAC keys
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

Notes:

- Signing is AWS Signature V4, written in this package. It is tested with the
  official AWS example requests. There is no AWS SDK dependency.
- `put` sends one request. S3 limits one request to 5 GiB.
- `putStream` switches to multipart upload when the stream is bigger than
  `multipartPartSize` (8 MiB by default). It keeps one part in memory at a
  time. S3 allows 10,000 parts, so the limit is about 78 GiB with 8 MiB parts.
  Raise `multipartPartSize` for bigger files.
- `copy` and `move` use server-side copy. S3 limits this to 5 GiB.
- Signed URLs can live at most 7 days. This is an S3 rule.
- Set `urlBase` to serve public files from a CDN.
- Pass your own `httpClient` to reuse a connection pool, or to mock S3 in
  tests.

## Local signed URLs

`LocalDriver.getSignedUrl` returns `<urlBase>/<key>?expires=...&signature=...`.
Check the signature in the route that serves the file:

```dart
LocalDriver local = LocalDriver(LocalDriverConfig(
  root: 'storage',
  urlBase: 'https://app.test/files',
  appKey: Env.get('APP_KEY'),
));

// In your route for GET /files/*
bool ok = local.verifySignedUrl(keyFromPath, request.uri.queryParameters);
if (!ok) {
  // return 403
}
```

## Tests and fakes

```dart
Disk fake = drive.fake('s3'); // drive.use('s3') now writes to memory
await uploadAvatar(); // your code under test
expect(await fake.exists('avatars/1.png'), isTrue);
drive.restore('s3');
```

## Your own driver

Implement `DriverContract` and register it:

```dart
class DropboxDriver implements DriverContract { ... }

drive.register('dropbox', DropboxDriver(...));
await drive.use('dropbox').put('a.txt', 'hello');
```

Keys reach your driver already normalized. Throw `FileNotFoundException` and
`PermissionDeniedException` where they fit. `Disk` wraps any other error in
`DriverException`.

## Running the tests

```sh
dart test
```

The MinIO integration tests skip when MinIO is not running. To run them:

```sh
docker run -d --rm --name dox-storage-minio -p 9100:9000 -p 9101:9001 \
  -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
  cgr.dev/chainguard/minio:latest server /tmp/data --console-address :9001
dart test
docker rm -f dox-storage-minio
```

Set `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY` to use another
MinIO server.

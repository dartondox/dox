# dox_storage

File storage for Dart. One API for local disk, AWS S3 and S3-compatible services.

[![pub package](https://img.shields.io/pub/v/dox_storage.svg)](https://pub.dev/packages/dox_storage)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/develop/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

```bash
dart pub add dox_storage
```

Dox 3.x is in alpha (`3.0.0-alpha.4`). The API can still change before the stable release.

## Use it

```dart
import 'dart:typed_data';

import 'package:dox_storage/dox_storage.dart';

void main() async {
  DriveManager drive = DriveManager(
    defaultDisk: 'local',
    disks: <String, DriverContract>{
      'local': LocalDriver(LocalDriverConfig(root: 'storage')),
      's3': S3Driver(S3DriverConfig(
        bucket: 'my-bucket',
        region: 'us-east-1',
        accessKeyId: 'AKIA...',
        secretAccessKey: '...',
      )),
    },
  );

  Disk disk = drive.use(); // the default disk
  await disk.put('notes/a.txt', 'hello');
  Uint8List data = await disk.get('notes/a.txt');
  print(await disk.exists('notes/a.txt')); // true
  await disk.delete('notes/a.txt');
}
```

In a Dox app, set the disks in `config/storage.dart` and use `Storage()`.

## Features

- Drivers: `LocalDriver`, `S3Driver` (AWS S3, Cloudflare R2, MinIO, DigitalOcean Spaces, GCS with HMAC keys) and `MemoryDriver`.
- `put`, `putStream`, `get`, `getStream`, `copy`, `move`, `delete`, `listAll`.
- Signed download URLs, and signed upload URLs on S3.
- Big streams go up as a multipart upload. Only one part is in memory at a time.
- Keys are checked. `..`, absolute paths and null bytes throw `InvalidKeyException`.
- `drive.fake('s3')` swaps a disk for memory in tests.
- AWS Signature V4 is written in this package. There is no AWS SDK dependency.

## Documentation

- [Storage package](https://dartondox.dev/latest/packages/storage/)
- [File storage in a Dox app](https://dartondox.dev/latest/digging-deeper/file-storage/)
- [API reference](https://pub.dev/documentation/dox_storage/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/develop/LICENSE).

## 3.0.0-alpha.9

- Version bump only, to match the other packages.

## 3.0.0-alpha.8

- Version bump only, to match the other packages.

## 3.0.0-alpha.7

- Perf: the S3 driver keeps the SigV4 signing key for each day. Before, every request ran 4 extra HMACs to make it again.
- Perf: the S3 driver hashes a body of 1 MiB or more (eg. an 8 MiB multipart part) in another isolate. Before, the sha256 blocked the event loop.

## 3.0.0-alpha.6

- Version bump only, to match the other packages.

## 3.0.0-alpha.5

- Version bump only, to match the other packages.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Version bump only, to match the other packages.

## 3.0.0-alpha.2

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.

## 3.0.0-alpha.1

- Initial version.
- `DriveManager` and `Disk` with a FlyDrive-like API.
- Drivers: `LocalDriver`, `S3Driver` (AWS S3, R2, MinIO, Spaces, GCS interop), `MemoryDriver`.
- AWS Signature V4 signing, presigned download and upload URLs, multipart upload.
- `DriveManager.fake()` for tests.

@Tags(<String>['integration'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_storage/dox_storage.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support/disk_contract.dart';

/// Runs against a real MinIO. Start it with:
///
/// docker run -d --rm --name dox-storage-minio -p 9100:9000 -p 9101:9001 \
///   -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
///   cgr.dev/chainguard/minio:latest server /tmp/data --console-address :9001
///
/// Skipped when MinIO is not reachable. Override with MINIO_ENDPOINT,
/// MINIO_ACCESS_KEY and MINIO_SECRET_KEY.
String endpoint =
    Platform.environment['MINIO_ENDPOINT'] ?? 'http://localhost:9100';
String accessKey = Platform.environment['MINIO_ACCESS_KEY'] ?? 'minioadmin';
String secretKey = Platform.environment['MINIO_SECRET_KEY'] ?? 'minioadmin';
const String bucket = 'dox-storage-test';

Future<bool> minioIsUp() async {
  try {
    http.Response response = await http
        .get(Uri.parse('$endpoint/minio/health/live'))
        .timeout(const Duration(seconds: 2));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

S3Driver minioDriver({String? secret, int? partSize}) {
  return S3Driver(
    S3DriverConfig(
      bucket: bucket,
      region: 'us-east-1',
      accessKeyId: accessKey,
      secretAccessKey: secret ?? secretKey,
      endpoint: endpoint,
      forcePathStyle: true,
      supportsAcl: false,
      multipartPartSize: partSize ?? StorageConstants.defaultMultipartPartSize,
    ),
  );
}

Future<void> createBucket(S3Driver driver) async {
  http.Response response =
      await driver.client.send('PUT', driver.client.bucketUri());
  // 409 means the bucket is already there.
  if (response.statusCode != 200 && response.statusCode != 409) {
    throw StateError('Could not create bucket: ${response.body}');
  }
}

Future<void> main() async {
  bool up = await minioIsUp();
  String? skip = up ? null : 'MinIO is not reachable at $endpoint';

  group('MinIO', () {
    S3Driver? contractDriver;

    runDiskContract(
      'S3Driver on MinIO',
      () async {
        contractDriver = minioDriver();
        await createBucket(contractDriver!);
        return Disk(contractDriver!);
      },
      cleanUp: () async {
        contractDriver?.close();
      },
    );

    group('S3Driver on MinIO extras', () {
      late S3Driver driver;
      late Disk disk;

      setUpAll(() async {
        driver = minioDriver(partSize: StorageConstants.minMultipartPartSize);
        await createBucket(driver);
        disk = Disk(driver);
      });

      tearDownAll(() async {
        await disk.deleteAll('extras');
        driver.close();
      });

      test('signed GET URL works without credentials', () async {
        await disk.put('extras/signed.txt', 'secret content');
        String url = await disk.getSignedUrl(
          'extras/signed.txt',
          options: const SignedUrlOptions(
            contentDisposition: 'attachment; filename="s.txt"',
          ),
        );
        http.Response response = await http.get(Uri.parse(url));
        expect(response.statusCode, 200);
        expect(response.body, 'secret content');
        expect(
          response.headers['content-disposition'],
          'attachment; filename="s.txt"',
        );
      });

      test('plain GET without a signature is denied', () async {
        await disk.put('extras/private.txt', 'x');
        http.Response response =
            await http.get(Uri.parse(await disk.getUrl('extras/private.txt')));
        expect(response.statusCode, 403);
      });

      test('signed upload URL accepts a PUT', () async {
        String url = await disk.getSignedUploadUrl(
          'extras/uploaded file.json',
          options: const SignedUrlOptions(contentType: 'application/json'),
        );
        http.Response response = await http.put(
          Uri.parse(url),
          headers: <String, String>{'content-type': 'application/json'},
          body: '{"ok":true}',
        );
        expect(response.statusCode, 200, reason: response.body);
        expect(
            await disk.getString('extras/uploaded file.json'), '{"ok":true}');
        ObjectMetaData meta =
            await disk.getMetaData('extras/uploaded file.json');
        expect(meta.contentType, 'application/json');
      });

      test('multipart upload of 11 MiB', () async {
        int size = 11 * 1024 * 1024;
        Uint8List data = Uint8List(size);
        for (int i = 0; i < size; i++) {
          data[i] = i % 251;
        }
        Stream<List<int>> chunks() async* {
          for (int i = 0; i < size; i += 1024 * 1024) {
            yield Uint8List.sublistView(data, i, i + 1024 * 1024);
          }
        }

        await disk.putStream('extras/big.bin', chunks());
        ObjectMetaData meta = await disk.getMetaData('extras/big.bin');
        expect(meta.size, size);
        // Multipart etags end with "-<parts>".
        expect(meta.etag, endsWith('-3'));
        expect(await disk.get('extras/big.bin'), data);
      }, timeout: const Timeout(Duration(minutes: 2)));

      test('wrong secret gives PermissionDeniedException', () async {
        S3Driver bad = minioDriver(secret: 'wrong-secret');
        addTearDown(bad.close);
        expect(
          Disk(bad).get('extras/signed.txt'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('special characters in keys', () async {
        String key = "extras/a+b=c&d/it's (1) ~ ü.txt";
        await disk.put(key, 'weird');
        expect(await disk.getString(key), 'weird');
        ListResult result = await disk.listAll('extras/a+b=c&d');
        expect(result.objects.single.key, key);
        String url = await disk.getSignedUrl(key);
        expect((await http.get(Uri.parse(url))).body, 'weird');
      });
    });
  }, skip: skip);
}

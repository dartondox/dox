import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dox_storage/dox_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Records requests and answers with a queued response.
class FakeS3 {
  final List<http.Request> requests = <http.Request>[];
  final List<http.Response> responses = <http.Response>[];

  void reply(int status, [String body = '', Map<String, String>? headers]) {
    responses.add(
      http.Response(body, status, headers: headers ?? <String, String>{}),
    );
  }

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    if (responses.isEmpty) {
      return http.Response('', 200);
    }
    return responses.removeAt(0);
  }

  MockClient client() {
    return MockClient(handle);
  }
}

S3DriverConfig config({
  bool forcePathStyle = true,
  bool supportsAcl = true,
  bool supportsBatchDelete = true,
  int partSize = StorageConstants.defaultMultipartPartSize,
  String? urlBase,
}) {
  return S3DriverConfig(
    bucket: 'my-bucket',
    region: 'us-east-1',
    accessKeyId: 'AKIDEXAMPLE',
    secretAccessKey: 'secret',
    endpoint: 'http://localhost:9000',
    forcePathStyle: forcePathStyle,
    supportsAcl: supportsAcl,
    supportsBatchDelete: supportsBatchDelete,
    multipartPartSize: partSize,
    urlBase: urlBase,
  );
}

void main() {
  late FakeS3 s3;
  FixedClock clock = FixedClock(DateTime.utc(2025));

  setUp(() {
    s3 = FakeS3();
  });

  Disk diskWith(S3DriverConfig cfg) {
    return Disk(S3Driver(cfg, httpClient: s3.client(), clock: clock));
  }

  group('S3Driver requests', () {
    test('put sends a signed PUT with content type and ACL', () async {
      await diskWith(config()).put('a dir/file.txt', 'hello');
      http.Request request = s3.requests.single;
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        'http://localhost:9000/my-bucket/a%20dir/file.txt',
      );
      expect(request.headers['content-type'], 'text/plain');
      expect(request.headers['x-amz-acl'], 'private');
      expect(
        request.headers['x-amz-content-sha256'],
        sha256.convert(utf8.encode('hello')).toString(),
      );
      expect(request.headers['x-amz-date'], '20250101T000000Z');
      expect(
        request.headers['authorization'],
        startsWith(
          'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20250101/us-east-1/s3/',
        ),
      );
      expect(request.headers.containsKey('host'), isFalse);
      expect(request.body, 'hello');
    });

    test('virtual host style puts the bucket in the host', () async {
      await diskWith(config(forcePathStyle: false)).put('k.txt', 'x');
      expect(
        s3.requests.single.url.toString(),
        'http://my-bucket.localhost:9000/k.txt',
      );
    });

    test('default endpoint is AWS for the region', () async {
      S3Driver driver = S3Driver(
        const S3DriverConfig(
          bucket: 'b',
          region: 'eu-west-1',
          accessKeyId: 'a',
          secretAccessKey: 's',
        ),
        httpClient: s3.client(),
      );
      expect(
        await Disk(driver).getUrl('x.png'),
        'https://b.s3.eu-west-1.amazonaws.com/x.png',
      );
    });

    test('supportsAcl false sends no ACL header', () async {
      await diskWith(config(supportsAcl: false)).put('k.txt', 'x');
      expect(s3.requests.single.headers.containsKey('x-amz-acl'), isFalse);
    });

    test('public visibility maps to public-read', () async {
      await diskWith(config()).put(
        'k.txt',
        'x',
        options: const WriteOptions(visibility: Visibility.public),
      );
      expect(s3.requests.single.headers['x-amz-acl'], 'public-read');
    });

    test('copy uses x-amz-copy-source', () async {
      s3.reply(200, '<CopyObjectResult></CopyObjectResult>');
      await diskWith(config()).copy('from me.txt', 'to.txt');
      http.Request request = s3.requests.single;
      expect(request.headers['x-amz-copy-source'], '/my-bucket/from%20me.txt');
      expect(request.url.path, '/my-bucket/to.txt');
    });

    test('copy with an error body throws', () async {
      s3.reply(200, '<Error><Code>InternalError</Code></Error>');
      expect(
        diskWith(config()).copy('a.txt', 'b.txt'),
        throwsA(isA<DriverException>()),
      );
    });

    test('move copies then deletes', () async {
      s3.reply(200, '<CopyObjectResult/>');
      s3.reply(204);
      await diskWith(config()).move('a.txt', 'b.txt');
      expect(s3.requests.map((http.Request r) => r.method), <String>[
        'PUT',
        'DELETE',
      ]);
    });
  });

  group('S3Driver errors', () {
    test('404 NoSuchKey becomes FileNotFoundException', () async {
      s3.reply(
        404,
        '<Error><Code>NoSuchKey</Code><Message>gone</Message></Error>',
      );
      expect(
        diskWith(config()).get('a.txt'),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('403 becomes PermissionDeniedException', () async {
      s3.reply(403, '<Error><Code>AccessDenied</Code></Error>');
      expect(
        diskWith(config()).get('a.txt'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('NoSuchBucket is a DriverException, not a missing file', () async {
      s3.reply(404, '<Error><Code>NoSuchBucket</Code></Error>');
      expect(
        diskWith(config()).get('a.txt'),
        throwsA(
          isA<DriverException>().having(
            (DriverException e) => e.message,
            'message',
            contains('NoSuchBucket'),
          ),
        ),
      );
    });

    test('500 becomes DriverException with the key', () async {
      s3.reply(500, '<Error><Code>InternalError</Code></Error>');
      expect(
        diskWith(config()).put('k.txt', 'x'),
        throwsA(
          isA<DriverException>().having(
            (DriverException e) => e.key,
            'key',
            'k.txt',
          ),
        ),
      );
    });

    test('exists is false on 404, true on 200', () async {
      s3.reply(404);
      s3.reply(200);
      Disk disk = diskWith(config());
      expect(await disk.exists('a.txt'), isFalse);
      expect(await disk.exists('a.txt'), isTrue);
      expect(s3.requests.first.method, 'HEAD');
    });

    test('delete ignores 404', () async {
      s3.reply(404);
      await diskWith(config()).delete('a.txt');
    });
  });

  group('S3Driver metadata and visibility', () {
    test('getMetaData reads HEAD headers', () async {
      s3.reply(200, '', <String, String>{
        'content-length': '42',
        'content-type': 'image/png',
        'last-modified': 'Wed, 01 Jan 2025 10:00:00 GMT',
        'etag': '"abc123"',
      });
      ObjectMetaData meta = await diskWith(config()).getMetaData('a.png');
      expect(meta.size, 42);
      expect(meta.contentType, 'image/png');
      expect(meta.lastModified, DateTime.utc(2025, 1, 1, 10));
      expect(meta.etag, 'abc123');
    });

    test('getVisibility reads the ACL', () async {
      s3.reply(200, '''
<AccessControlPolicy><AccessControlList>
<Grant><Grantee><ID>owner</ID></Grantee><Permission>FULL_CONTROL</Permission></Grant>
<Grant><Grantee><URI>http://acs.amazonaws.com/groups/global/AllUsers</URI></Grantee><Permission>READ</Permission></Grant>
</AccessControlList></AccessControlPolicy>''');
      s3.reply(200, '''
<AccessControlPolicy><AccessControlList>
<Grant><Grantee><ID>owner</ID></Grantee><Permission>FULL_CONTROL</Permission></Grant>
</AccessControlList></AccessControlPolicy>''');
      Disk disk = diskWith(config());
      expect(await disk.getVisibility('a.txt'), Visibility.public);
      expect(await disk.getVisibility('a.txt'), Visibility.private);
      expect(s3.requests.first.url.query, 'acl=');
    });

    test('setVisibility sends PUT ?acl', () async {
      await diskWith(config()).setVisibility('a.txt', Visibility.public);
      http.Request request = s3.requests.single;
      expect(request.method, 'PUT');
      expect(request.url.query, 'acl=');
      expect(request.headers['x-amz-acl'], 'public-read');
    });

    test('without ACL support visibility makes no requests', () async {
      Disk disk = diskWith(config(supportsAcl: false));
      await disk.setVisibility('a.txt', Visibility.public);
      expect(await disk.getVisibility('a.txt'), Visibility.private);
      expect(s3.requests, isEmpty);
    });
  });

  group('S3Driver URLs', () {
    test('getUrl uses urlBase when set', () async {
      Disk disk = diskWith(config(urlBase: 'https://cdn.test/'));
      expect(await disk.getUrl('a b.png'), 'https://cdn.test/a%20b.png');
    });

    test('getSignedUrl presigns GET with response overrides', () async {
      String url = await diskWith(config()).getSignedUrl(
        'report.pdf',
        options: const SignedUrlOptions(
          expiresIn: Duration(minutes: 5),
          contentDisposition: 'attachment; filename="r.pdf"',
        ),
      );
      Uri uri = Uri.parse(url);
      expect(uri.path, '/my-bucket/report.pdf');
      expect(uri.queryParameters['X-Amz-Expires'], '300');
      expect(uri.queryParameters['X-Amz-Date'], '20250101T000000Z');
      expect(
        uri.queryParameters['response-content-disposition'],
        'attachment; filename="r.pdf"',
      );
      expect(uri.queryParameters['X-Amz-Signature'], hasLength(64));
      expect(s3.requests, isEmpty);
    });

    test('getSignedUploadUrl signs the content type', () async {
      String url = await diskWith(config()).getSignedUploadUrl(
        'up.png',
        options: const SignedUrlOptions(contentType: 'image/png'),
      );
      Uri uri = Uri.parse(url);
      expect(uri.queryParameters['X-Amz-SignedHeaders'], 'content-type;host');
      expect(uri.queryParameters['X-Amz-Expires'], '1800');
    });

    test('signed URLs longer than 7 days are rejected', () async {
      expect(
        diskWith(config()).getSignedUrl(
          'a.txt',
          options: const SignedUrlOptions(expiresIn: Duration(days: 8)),
        ),
        throwsA(isA<UnsupportedOperationException>()),
      );
    });
  });

  group('S3Driver listAll and deleteAll', () {
    String listPage({
      required List<String> keys,
      List<String> prefixes = const <String>[],
      String? next,
    }) {
      StringBuffer xml = StringBuffer('<ListBucketResult><Prefix>p/</Prefix>');
      for (String key in keys) {
        xml.write('<Contents><Key>$key</Key><Size>1</Size></Contents>');
      }
      for (String prefix in prefixes) {
        xml.write('<CommonPrefixes><Prefix>$prefix</Prefix></CommonPrefixes>');
      }
      xml.write('<IsTruncated>${next != null}</IsTruncated>');
      if (next != null) {
        xml.write('<NextContinuationToken>$next</NextContinuationToken>');
      }
      xml.write('</ListBucketResult>');
      return xml.toString();
    }

    test('parses files, folders and XML entities', () async {
      s3.reply(
        200,
        listPage(
          keys: <String>['p/a&amp;b.txt', 'p/'],
          prefixes: <String>['p/sub/'],
        ),
      );
      ListResult result = await diskWith(config()).listAll('p');
      expect(
        result.objects.map((DriveEntry e) => '${e.runtimeType}:${e.key}'),
        <String>['DriveFile:p/a&b.txt', 'DriveDirectory:p/sub'],
      );
      Uri url = s3.requests.single.url;
      expect(url.queryParameters['list-type'], '2');
      expect(url.queryParameters['prefix'], 'p/');
      expect(url.queryParameters['delimiter'], '/');
    });

    test('without a limit it follows every page', () async {
      s3.reply(200, listPage(keys: <String>['p/1'], next: 'tok'));
      s3.reply(200, listPage(keys: <String>['p/2']));
      ListResult result = await diskWith(config())
          .listAll('p', const ListOptions(recursive: true));
      expect(result.objects.length, 2);
      expect(result.paginationToken, isNull);
      expect(s3.requests[1].url.queryParameters['continuation-token'], 'tok');
      expect(
        s3.requests[0].url.queryParameters.containsKey('delimiter'),
        isFalse,
      );
    });

    test('with a limit it returns one page and a token', () async {
      s3.reply(200, listPage(keys: <String>['p/1'], next: 'tok'));
      ListResult result = await diskWith(config())
          .listAll('p', const ListOptions(limit: 1));
      expect(result.paginationToken, 'tok');
      expect(s3.requests.single.url.queryParameters['max-keys'], '1');
    });

    test('deleteAll sends DeleteObjects with Content-MD5', () async {
      s3.reply(200, listPage(keys: <String>['p/1', 'p/<2>']));
      s3.reply(200, '<DeleteResult></DeleteResult>');
      await diskWith(config()).deleteAll('p');
      http.Request request = s3.requests[1];
      expect(request.method, 'POST');
      expect(request.url.query, 'delete=');
      expect(request.body, contains('<Key>p/&lt;2&gt;</Key>'));
      expect(
        request.headers['content-md5'],
        base64.encode(md5.convert(request.bodyBytes).bytes),
      );
    });

    test('deleteAll without batch support deletes one by one', () async {
      s3.reply(200, listPage(keys: <String>['p/1', 'p/2']));
      await diskWith(config(supportsBatchDelete: false)).deleteAll('p');
      expect(s3.requests.skip(1).map((http.Request r) => r.method), <String>[
        'DELETE',
        'DELETE',
      ]);
    });
  });

  group('S3Driver putStream', () {
    Stream<List<int>> bytes(int count) {
      return Stream<List<int>>.fromIterable(<List<int>>[
        List<int>.filled(count ~/ 2, 1),
        List<int>.filled(count - count ~/ 2, 2),
      ]);
    }

    test('small stream uses a single PUT', () async {
      await diskWith(config(partSize: 10)).putStream('s.bin', bytes(6));
      expect(s3.requests.single.method, 'PUT');
      expect(s3.requests.single.bodyBytes.length, 6);
    });

    test('big stream uses multipart upload', () async {
      s3.reply(
        200,
        '<InitiateMultipartUploadResult><UploadId>U1</UploadId>'
        '</InitiateMultipartUploadResult>',
      );
      s3.reply(200, '', <String, String>{'etag': '"e1"'});
      s3.reply(200, '', <String, String>{'etag': '"e2"'});
      s3.reply(200, '', <String, String>{'etag': '"e3"'});
      s3.reply(200, '<CompleteMultipartUploadResult/>');

      await diskWith(config(partSize: 10)).putStream('big.bin', bytes(25));

      List<String> calls = <String>[];
      for (http.Request r in s3.requests) {
        calls.add('${r.method} ${r.url.query} ${r.bodyBytes.length}');
      }
      expect(calls[0], startsWith('POST uploads='));
      expect(calls[1], 'PUT partNumber=1&uploadId=U1 10');
      expect(calls[2], 'PUT partNumber=2&uploadId=U1 10');
      expect(calls[3], 'PUT partNumber=3&uploadId=U1 5');
      expect(calls[4], startsWith('POST uploadId=U1'));
      expect(
        s3.requests[0].headers['content-type'],
        'application/octet-stream',
      );
      expect(
        s3.requests[4].body,
        '<CompleteMultipartUpload>'
        '<Part><PartNumber>1</PartNumber><ETag>&quot;e1&quot;</ETag></Part>'
        '<Part><PartNumber>2</PartNumber><ETag>&quot;e2&quot;</ETag></Part>'
        '<Part><PartNumber>3</PartNumber><ETag>&quot;e3&quot;</ETag></Part>'
        '</CompleteMultipartUpload>',
      );
    });

    test('a failed part aborts the upload', () async {
      s3.reply(200, '<UploadId>U1</UploadId>');
      s3.reply(500, '<Error><Code>InternalError</Code></Error>');
      s3.reply(204);
      await expectLater(
        diskWith(config(partSize: 10)).putStream('big.bin', bytes(25)),
        throwsA(isA<DriverException>()),
      );
      expect(s3.requests.last.method, 'DELETE');
      expect(s3.requests.last.url.query, 'uploadId=U1');
    });

    test('stream errors are wrapped and abort the upload', () async {
      s3.reply(200, '<UploadId>U1</UploadId>');
      s3.reply(200, '', <String, String>{'etag': '"e1"'});
      Stream<List<int>> broken() async* {
        yield Uint8List(12);
        throw StateError('source failed');
      }

      await expectLater(
        diskWith(config(partSize: 10)).putStream('big.bin', broken()),
        throwsA(isA<DriverException>()),
      );
      expect(s3.requests.last.method, 'DELETE');
    });
  });
}

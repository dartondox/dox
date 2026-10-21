import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import 'requirements/handler.dart';

AppConfig streamConfig = AppConfig(
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
  serverPort: 50030,
  totalIsolate: 1,
  responseHandler: ResponseHandler(),
  maxBodySize: 1024,
  maxMultipartSize: 3 * 1024 * 1024,
  trustedProxies: <String>['127.0.0.1', '::1'],
);

String baseUrl = 'http://localhost:${streamConfig.serverPort}';
const String boundary = 'doxtestboundary';

/// a multipart body with one file field of [size] bytes
List<int> multipart(int size) {
  return <int>[
    ...utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="note"\r\n\r\n'
      'héllo\r\n'
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="file"; filename="a.bin"\r\n'
      'Content-Type: application/octet-stream\r\n\r\n',
    ),
    ...List<int>.filled(size, 65),
    ...utf8.encode('\r\n--$boundary--\r\n'),
  ];
}

/// send [body] with HttpClient. chunked=true sends no Content-Length,
/// so the server must count bytes while it reads.
Future<(int, String)> send(
  String path,
  List<int> body, {
  required String contentType,
  bool chunked = false,
}) async {
  HttpClient client = HttpClient();
  try {
    HttpClientRequest req = await client.postUrl(Uri.parse('$baseUrl$path'));
    req.headers.set(HttpHeaders.contentTypeHeader, contentType);
    if (chunked) {
      req.contentLength = -1;
      for (int i = 0; i < body.length; i += 64 * 1024) {
        req.add(body.sublist(i, (i + 64 * 1024).clamp(0, body.length)));
        await req.flush();
      }
    } else {
      req.contentLength = body.length;
      req.add(body);
    }
    HttpClientResponse res = await req.close();
    return (res.statusCode, await utf8.decodeStream(res));
  } finally {
    client.close(force: true);
  }
}

void main() {
  late File bigFile;

  group('Streaming |', () {
    setUpAll(() async {
      bigFile = File('${Directory.systemTemp.path}/dox-range-test.txt')
        ..writeAsStringSync('0123456789abcdefghij');
      Route.post('/echo', (DoxRequest req) => req.all());
      Route.post('/upload', (DoxRequest req) async {
        RequestFile file = req.input('file');
        return <String, dynamic>{
          'note': req.input('note'),
          'length': file.length,
          'on_disk': file.file != null,
          'temp': file.file?.path,
          'temp_exists': file.file?.existsSync(),
          'stream_length': await file.stream().fold<int>(
            0,
            (int a, List<int> b) => a + b.length,
          ),
        };
      });
      Route.post('/store', (DoxRequest req) async {
        RequestFile file = req.input('file');
        String temp = file.file!.path;
        String saved = await file.store('stream-test');
        return <String, dynamic>{
          'saved': saved,
          'temp_exists': File(temp).existsSync(),
          'bytes': (await file.bytes).length,
        };
      });
      Route.get('/stream', (DoxRequest req) {
        return Stream<List<int>>.fromIterable(<List<int>>[
          for (int i = 0; i < 100; i++) utf8.encode('$i,'),
        ]);
      });
      Route.get('/file', (DoxRequest req) => bigFile);
      Route.get('/ip', (DoxRequest req) {
        return <String, dynamic>{'ip': req.ip(), 'scheme': req.scheme()};
      });
      await startHttpServer(streamConfig);
    });

    tearDownAll(() async {
      await Dox().server.close();
      Directory storage = Directory(
        '${Directory.current.path}/storage/stream-test',
      );
      if (storage.existsSync()) storage.deleteSync(recursive: true);
      if (bigFile.existsSync()) bigFile.deleteSync();
    });

    test('json under the limit is parsed', () async {
      (int, String) res = await send(
        '/echo',
        utf8.encode('{"a":1}'),
        contentType: 'application/json',
      );
      expect(res.$1, 200);
      expect(jsonDecode(res.$2), <String, dynamic>{'a': 1});
    });

    test('urlencoded body is parsed', () async {
      http.Response res = await http.post(
        Uri.parse('$baseUrl/echo'),
        body: <String, String>{'name': 'dox', 'q': 'a b'},
      );
      expect(jsonDecode(res.body), <String, dynamic>{
        'name': 'dox',
        'q': 'a b',
      });
    });

    test('413 by Content-Length', () async {
      (int, String) res = await send(
        '/echo',
        utf8.encode('{"a":"${'x' * 2000}"}'),
        contentType: 'application/json',
      );
      expect(res.$1, HttpStatus.requestEntityTooLarge);
    });

    test('413 while streaming (no Content-Length)', () async {
      (int, String) res = await send(
        '/echo',
        utf8.encode('{"a":"${'x' * 4000}"}'),
        contentType: 'application/json',
        chunked: true,
      );
      expect(res.$1, HttpStatus.requestEntityTooLarge);
    });

    test('413 for multipart over its own limit', () async {
      (int, String) res = await send(
        '/upload',
        multipart(4 * 1024 * 1024),
        contentType: 'multipart/form-data; boundary=$boundary',
      );
      expect(res.$1, HttpStatus.requestEntityTooLarge);
    });

    test('413 for streamed multipart over its limit', () async {
      (int, String) res = await send(
        '/upload',
        multipart(3 * 1024 * 1024 + 10),
        contentType: 'multipart/form-data; boundary=$boundary',
        chunked: true,
      );
      expect(res.$1, HttpStatus.requestEntityTooLarge);
    });

    test('small upload stays in memory', () async {
      (int, String) res = await send(
        '/upload',
        multipart(1000),
        contentType: 'multipart/form-data; boundary=$boundary',
      );
      Map<String, dynamic> data = jsonDecode(res.$2);
      expect(data['note'], 'héllo');
      expect(data['length'], 1000);
      expect(data['on_disk'], false);
      expect(data['stream_length'], 1000);
    });

    test('big upload goes to a temp file, deleted after response', () async {
      int size = 2 * 1024 * 1024;
      (int, String) res = await send(
        '/upload',
        multipart(size),
        contentType: 'multipart/form-data; boundary=$boundary',
        chunked: true,
      );
      expect(res.$1, 200);
      Map<String, dynamic> data = jsonDecode(res.$2);
      expect(data['length'], size);
      expect(data['on_disk'], true);
      expect(data['temp_exists'], true);
      expect(data['stream_length'], size);

      File temp = File(data['temp']);
      for (int i = 0; i < 50 && temp.existsSync(); i++) {
        await Future<void>.delayed(Duration(milliseconds: 10));
      }
      expect(temp.existsSync(), false);
    });

    test('store() moves the temp file and bytes still work', () async {
      int size = 2 * 1024 * 1024;
      (int, String) res = await send(
        '/store',
        multipart(size),
        contentType: 'multipart/form-data; boundary=$boundary',
      );
      Map<String, dynamic> data = jsonDecode(res.$2);
      expect(data['temp_exists'], false);
      expect(data['bytes'], size);
      File saved = File('${Directory.current.path}/storage${data['saved']}');
      expect(saved.lengthSync(), size);
    });

    test('stream response is piped', () async {
      http.Response res = await http.get(Uri.parse('$baseUrl/stream'));
      expect(res.statusCode, 200);
      expect(res.body.split(',').length, 101);
    });

    test('json response has Content-Length', () async {
      http.Response res = await http.post(
        Uri.parse('$baseUrl/echo'),
        headers: <String, String>{'content-type': 'application/json'},
        body: '{"a":"ü"}',
      );
      expect(res.headers['content-length'], '${res.bodyBytes.length}');
      expect(res.headers['content-type'], contains('application/json'));
    });

    test('file response with Content-Length, type and Range', () async {
      Uri url = Uri.parse('$baseUrl/file');
      http.Response full = await http.get(url);
      expect(full.statusCode, 200);
      expect(full.body, '0123456789abcdefghij');
      expect(full.headers['content-length'], '20');
      expect(full.headers['content-type'], startsWith('text/plain'));
      expect(full.headers['accept-ranges'], 'bytes');

      http.Response part = await http.get(
        url,
        headers: <String, String>{'range': 'bytes=2-5'},
      );
      expect(part.statusCode, 206);
      expect(part.body, '2345');
      expect(part.headers['content-range'], 'bytes 2-5/20');

      http.Response tail = await http.get(
        url,
        headers: <String, String>{'range': 'bytes=-3'},
      );
      expect(tail.body, 'hij');

      http.Response open = await http.get(
        url,
        headers: <String, String>{'range': 'bytes=18-'},
      );
      expect(open.body, 'ij');

      http.Response bad = await http.get(
        url,
        headers: <String, String>{'range': 'bytes=50-60'},
      );
      expect(bad.statusCode, 416);
      expect(bad.headers['content-range'], 'bytes */20');
    });

    test('trusted proxy: X-Forwarded-For and X-Forwarded-Proto', () async {
      http.Response res = await http.get(
        Uri.parse('$baseUrl/ip'),
        headers: <String, String>{
          'x-forwarded-for': '6.6.6.6, 1.2.3.4',
          'x-forwarded-proto': 'https',
        },
      );
      expect(jsonDecode(res.body), <String, dynamic>{
        'ip': '1.2.3.4',
        'scheme': 'https',
      });

      http.Response plain = await http.get(Uri.parse('$baseUrl/ip'));
      expect(jsonDecode(plain.body)['scheme'], 'http');
    });
  });
}

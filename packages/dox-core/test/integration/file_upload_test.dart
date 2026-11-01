import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import 'requirements/config/app.dart';

String get baseUrl => 'http://localhost:${Dox().server.httpServer.port}';

void main() {
  group('Http |', () {
    setUpAll(() async {
      await startHttpServer(config);
    });

    tearDownAll(() async {
      await Dox().server.close();
    });

    test('a File response sends nosniff', () async {
      String dir = Directory.current.path;
      Route.get('/file/raw', (DoxRequest req) {
        return File('$dir/test/integration/storage/dox.png');
      });
      http.Response res = await http.get(Uri.parse('$baseUrl/file/raw'));
      expect(res.statusCode, 200);
      expect(res.headers['x-content-type-options'], 'nosniff');
    });

    test(
      'many backslashes in a part header do not freeze the server',
      () async {
        Route.post('/redos', (DoxRequest req) => 'ok');

        String boundary = 'dox-boundary';
        String body =
            '--$boundary\r\n'
            'Content-Disposition: form-data; name="${'\\' * 60}\r\n\r\n'
            'x\r\n--$boundary--\r\n';
        http.Response res = await http
            .post(
              Uri.parse('$baseUrl/redos'),
              headers: <String, String>{
                'content-type': 'multipart/form-data; boundary=$boundary',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 5));
        expect(res.statusCode, isNot(200));
      },
    );
    test('multipart with no boundary gives 400', () async {
      Route.post('/no-boundary', (DoxRequest req) => 'ok');
      http.Response res = await http.post(
        Uri.parse('$baseUrl/no-boundary'),
        headers: <String, String>{'content-type': 'multipart/form-data'},
        body: 'x',
      );
      expect(res.statusCode, 400);
    });

    test('multipart part with no Content-Disposition gives 400', () async {
      Route.post('/no-disposition', (DoxRequest req) => 'ok');
      String boundary = 'dox-boundary';
      http.Response res = await http.post(
        Uri.parse('$baseUrl/no-disposition'),
        headers: <String, String>{
          'content-type': 'multipart/form-data; boundary=$boundary',
        },
        body:
            '--$boundary\r\nContent-Type: text/plain\r\n\r\nx\r\n'
            '--$boundary--\r\n',
      );
      expect(res.statusCode, 400);
    });
  });
}

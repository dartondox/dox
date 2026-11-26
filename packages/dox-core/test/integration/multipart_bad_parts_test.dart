import 'dart:async';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';
import 'requirements/config/app.dart';

void main() {
  const String boundary = 'XBOUNDARY';

  String baseUrl() => 'http://localhost:${Dox().server.httpServer.port}';

  setUpAll(() async {
    await startHttpServer(
      AppConfig(
        appKey: testAppKey,
        serverPort: 0,
        totalIsolate: 1,
        cache: config.cache,
      ),
    );
    Route.post('/bad-part', (DoxRequest req) => 'ok ${req.body}');
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  Future<http.Response> send(String body) {
    return http
        .post(
          Uri.parse('${baseUrl()}/bad-part'),
          headers: <String, String>{
            'content-type': 'multipart/form-data; boundary=$boundary',
          },
          body: body.codeUnits,
        )
        .timeout(const Duration(seconds: 5));
  }

  String part(String headers) {
    return '--$boundary\r\n$headers\r\n\r\nvalue\r\n--$boundary--\r\n';
  }

  Map<String, String> bodies = <String, String>{
    'a space in a header name': part(
      'Content Disposition: form-data; name="a"',
    ),
    'a param with no name': part('Content-Disposition: form-data; ="a"'),
    'a param with no value': part('Content-Disposition: form-data; name'),
    'a quote that never ends': part('Content-Disposition: form-data; name="a'),
    'text after the params': part('Content-Disposition: form-data; name="a" x'),
    'no disposition type': part('Content-Disposition: ; name="a"'),
    'text after the boundary': '--${boundary}xx\r\n\r\n',
    'a header line with no colon': part('Content-Disposition'),
    'a header value that is not UTF-8': part(
      'Content-Disposition: form-data; name="a\xff"',
    ),
  };

  for (MapEntry<String, String> entry in bodies.entries) {
    test('${entry.key} gives 400', () async {
      http.Response res = await send(entry.value);
      expect(res.statusCode, 400, reason: res.body);
    });
  }

  /// the mime parser stops at the first byte after the end mark when the
  /// body has no parts. The request waited for ever.
  for (String body in <String>[
    '--$boundary--\r\nx',
    '\r\n--$boundary--\r\n\n',
    'text\r\n--$boundary--\r\nmore text\r\n',
    '--$boundary-- x\r\n',
  ]) {
    test('no parts, then ${body.length} bytes with text after the end mark: '
        'an empty body', () async {
      http.Response res = await send(body);
      expect(res.statusCode, 200, reason: res.body);
      expect(res.body, 'ok {}');
    });
  }

  test('text after the end mark of a body with parts is fine', () async {
    http.Response res = await send(
      '${part('Content-Disposition: form-data; name="a"')}more text',
    );
    expect(res.statusCode, 200);
    expect(res.body, contains('value'));
  });

  test('the server still answers', () async {
    http.Response res = await send(
      part('Content-Disposition: form-data; name="a"'),
    );
    expect(res.statusCode, 200);
    expect(res.body, contains('value'));
  });
}

import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';

int get port => Dox().server.httpServer.port;

Future<HttpClientResponse> send(String method, String path) async {
  HttpClient client = HttpClient();
  try {
    HttpClientRequest req = await client.open(method, 'localhost', port, path);
    return await req.close();
  } finally {
    client.close();
  }
}

void main() {
  setUpAll(() async {
    Route.get('/head/text', (DoxRequest req) => 'hello');
    Route.get('/head/user/{id}', (DoxRequest req, String id) {
      return <String, String>{'id': id};
    });
    await startHttpServer(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        // the OS picks a free port, so test files can run in parallel
        serverPort: 0,
        totalIsolate: 1,
        openApi: const OpenApiConfig(enabled: true),
      ),
    );
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  for (String path in <String>['/head/text', '/head/user/7', '/docs']) {
    test('HEAD $path answers like GET, with no body', () async {
      HttpClientResponse get = await send('GET', path);
      List<int> getBody = <int>[for (List<int> c in await get.toList()) ...c];
      HttpClientResponse head = await send('HEAD', path);
      List<int> headBody = <int>[for (List<int> c in await head.toList()) ...c];
      expect(get.statusCode, 200);
      expect(head.statusCode, 200);
      expect(headBody, isEmpty);
      expect(
        head.headers.contentType?.mimeType,
        get.headers.contentType?.mimeType,
      );
      expect(head.contentLength, getBody.length);
    });
  }

  test('HEAD of a missing route is 404', () async {
    HttpClientResponse head = await send('HEAD', '/head/missing');
    await head.drain<void>();
    expect(head.statusCode, 404);
  });
}

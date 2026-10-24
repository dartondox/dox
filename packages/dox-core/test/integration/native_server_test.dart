import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';

AppConfig nativeConfig() {
  return AppConfig(
    appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
    // the OS picks a free port, so test files can run in parallel
    serverPort: 0,
    totalIsolate: 1,
  );
}

void main() {
  tearDown(() async {
    Route.unmount('/raw/');
    await Dox().server.close();
  });

  test('the server is native', () async {
    Route.get('/backend', (DoxRequest req) => 'ok');
    await startHttpServer(nativeConfig());
    expect(Dox().server.httpServer, isA<NativeHttpServer>());

    HttpClient client = HttpClient();
    HttpClientResponse res = await (await client.get(
      'localhost',
      Dox().server.httpServer.port,
      '/backend',
    )).close();
    expect(res.statusCode, 200);
    client.close();
  });

  test('an app with a mount (like Socket.IO) is native too', () async {
    Route.mount('/raw/', (HttpRequest req) async {
      WebSocket ws = await NativeWebSocket.upgrade(req);
      ws.listen(ws.add);
    });
    await startHttpServer(nativeConfig());
    expect(Dox().server.httpServer, isA<NativeHttpServer>());

    WebSocket ws = await WebSocket.connect(
      'ws://127.0.0.1:${Dox().server.httpServer.port}/raw/',
    );
    ws.add('hi');
    expect(await ws.first, 'hi');
    await ws.close();
  });
}

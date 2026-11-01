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

  test('Route.websocket gives the open socket after middleware', () async {
    Route.websocket('/ws-echo', (WebSocket socket, DoxRequest req) {
      socket.listen((dynamic data) => socket.add('${req.input('who')}:$data'));
    }, middleware: <dynamic>[addWho]);
    await startHttpServer(nativeConfig());
    int port = Dox().server.httpServer.port;

    WebSocket ws = await WebSocket.connect('ws://127.0.0.1:$port/ws-echo');
    ws.add('hi');
    expect(await ws.first, 'mw:hi');
    await ws.close();

    // a plain GET is not an upgrade
    HttpClient client = HttpClient();
    HttpClientResponse res = await (await client.get(
      '127.0.0.1',
      port,
      '/ws-echo',
    )).close();
    expect(res.statusCode, 400);
    client.close();
  });

  test('Route.websocket accepts any site by default (no check)', () async {
    Route.websocket('/ws-open', (WebSocket socket, DoxRequest req) {
      socket.listen(socket.add);
    });
    await startHttpServer(nativeConfig());
    int port = Dox().server.httpServer.port;

    WebSocket ws = await WebSocket.connect(
      'ws://127.0.0.1:$port/ws-open',
      headers: <String, String>{'origin': 'https://other.example'},
    );
    ws.add('hi');
    expect(await ws.first, 'hi');
    await ws.close();
  });

  test('Route.websocket with allowedOrigins rejects another site', () async {
    Route.websocket('/ws-origin', (WebSocket socket, DoxRequest req) {
      socket.listen(socket.add);
    }, allowedOrigins: <String>[]);
    await startHttpServer(nativeConfig());
    int port = Dox().server.httpServer.port;

    // another site: 403, no socket
    await expectLater(
      WebSocket.connect(
        'ws://127.0.0.1:$port/ws-origin',
        headers: <String, String>{'origin': 'https://evil.example'},
      ),
      throwsA(isA<WebSocketException>()),
    );

    // the same host: allowed
    WebSocket ws = await WebSocket.connect(
      'ws://127.0.0.1:$port/ws-origin',
      headers: <String, String>{'origin': 'http://127.0.0.1:$port'},
    );
    ws.add('hi');
    expect(await ws.first, 'hi');
    await ws.close();
  });

  test('Route.websocket allows a site in allowedOrigins', () async {
    Route.websocket('/ws-origin-list', (WebSocket socket, DoxRequest req) {
      socket.listen(socket.add);
    }, allowedOrigins: <String>['https://app.example.com']);
    await startHttpServer(nativeConfig());
    int port = Dox().server.httpServer.port;

    WebSocket ws = await WebSocket.connect(
      'ws://127.0.0.1:$port/ws-origin-list',
      headers: <String, String>{'origin': 'https://app.example.com'},
    );
    ws.add('hi');
    expect(await ws.first, 'hi');
    await ws.close();
  });

  test('AppConfig.webSocketAllowedOrigins turns the check on', () async {
    Route.websocket('/ws-config', (WebSocket socket, DoxRequest req) {
      socket.listen(socket.add);
    });
    await startHttpServer(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        serverPort: 0,
        totalIsolate: 1,
        webSocketAllowedOrigins: <String>['https://app.example.com'],
      ),
    );
    int port = Dox().server.httpServer.port;

    await expectLater(
      WebSocket.connect(
        'ws://127.0.0.1:$port/ws-config',
        headers: <String, String>{'origin': 'https://evil.example'},
      ),
      throwsA(isA<WebSocketException>()),
    );
    WebSocket ws = await WebSocket.connect(
      'ws://127.0.0.1:$port/ws-config',
      headers: <String, String>{'origin': 'https://app.example.com'},
    );
    ws.add('hi');
    expect(await ws.first, 'hi');
    await ws.close();
  });
}

DoxRequest addWho(DoxRequest req) {
  req.add('who', 'mw');
  return req;
}

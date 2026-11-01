import 'dart:async';
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

  test('a mount that throws answers 500, the client does not hang', () async {
    Route.mount('/raw/', (HttpRequest req) async {
      throw StateError('mount failed');
    });
    await startHttpServer(nativeConfig());

    HttpClient client = HttpClient();
    HttpClientResponse res = await (await client.get(
      '127.0.0.1',
      Dox().server.httpServer.port,
      '/raw/x',
    )).close().timeout(const Duration(seconds: 5));
    expect(res.statusCode, 500);
    await res.drain<void>();
    client.close();
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

  test('Route.websocket closes on a message over maxMessageSize', () async {
    Route.websocket('/ws-small', (WebSocket socket, DoxRequest req) {
      socket.listen(socket.add);
    }, maxMessageSize: 10);
    await startHttpServer(nativeConfig());
    int port = Dox().server.httpServer.port;

    WebSocket ws = await WebSocket.connect('ws://127.0.0.1:$port/ws-small');
    ws.add('0123456789');
    expect(await ws.first, '0123456789');
    WebSocket big = await WebSocket.connect('ws://127.0.0.1:$port/ws-small');
    big.add('0123456789x');
    await big.drain<void>();
    expect(big.closeCode, 1009);
    await ws.close();
    expect(
      () => Route.websocket(
        '/ws-bad',
        (WebSocket s, DoxRequest r) {},
        maxMessageSize: 0,
      ),
      throwsArgumentError,
    );
  });

  test('AppConfig.idleTimeout closes an idle keep-alive connection', () async {
    Route.get('/idle', (DoxRequest req) => 'ok');
    await startHttpServer(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        serverPort: 0,
        totalIsolate: 1,
        idleTimeout: const Duration(milliseconds: 300),
      ),
    );
    Socket s = await Socket.connect('127.0.0.1', Dox().server.httpServer.port);
    Stopwatch clock = Stopwatch()..start();
    s.write('GET /idle HTTP/1.1\r\nHost: x\r\n\r\n');
    // the answer, then the end when the server closes the idle connection
    await s.drain<void>().timeout(const Duration(seconds: 5));
    expect(clock.elapsed, greaterThan(const Duration(milliseconds: 250)));
    s.destroy();
  });

  test('AppConfig.maxConnections makes a new client wait', () async {
    Route.get('/cap', (DoxRequest req) => 'ok');
    await startHttpServer(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        serverPort: 0,
        totalIsolate: 1,
        maxConnections: 1,
      ),
    );
    int port = Dox().server.httpServer.port;
    Socket first = await Socket.connect('127.0.0.1', port);
    first.write('GET /cap HTTP/1.1\r\nHost: x\r\n\r\n');
    await first.first.timeout(const Duration(seconds: 5));

    // the first connection is still open, so the second gets no answer
    Socket second = await Socket.connect('127.0.0.1', port);
    second.write('GET /cap HTTP/1.1\r\nHost: x\r\n\r\n');
    Future<List<int>> answer = second.first;
    await expectLater(
      answer.timeout(const Duration(milliseconds: 300)),
      throwsA(isA<TimeoutException>()),
    );

    // when the first closes, the second is served
    first.destroy();
    List<int> bytes = await answer.timeout(const Duration(seconds: 5));
    expect(String.fromCharCodes(bytes), contains('200'));
    second.destroy();
  });
}

DoxRequest addWho(DoxRequest req) {
  req.add('who', 'mw');
  return req;
}

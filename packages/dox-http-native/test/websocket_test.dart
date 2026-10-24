import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

/// `/ws` echoes every message, `/proto` answers with the subprotocol
/// `chat`, `/bye` closes at once with 4000, `/no` refuses with 403.
/// Anything else upgrades a request that may not be one.
void main() {
  late NativeHttpServer server;
  List<WebSocket> accepted = <WebSocket>[];

  String url(String path) => 'ws://127.0.0.1:${server.port}$path';

  Future<void> handle(HttpRequest req) async {
    switch (req.uri.path) {
      case '/no':
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
      case '/bye':
        WebSocket ws = await NativeWebSocket.upgrade(req);
        accepted.add(ws);
        await ws.close(4000, 'bye');
      default:
        WebSocket ws = await NativeWebSocket.upgrade(
          req,
          protocol: req.uri.path == '/proto' ? 'chat' : null,
          maxMessageSize: 10,
        );
        accepted.add(ws);
        ws.listen(ws.add);
    }
  }

  setUp(() async {
    accepted.clear();
    server = await NativeHttpServer.bind(0, address: '127.0.0.1');
    server.listen((HttpRequest req) {
      handle(req).catchError((Object _) {});
    });
  });

  tearDown(() => server.close(force: true));

  test('echoes text and binary', () async {
    WebSocket ws = await WebSocket.connect(url('/ws'));
    StreamIterator<dynamic> got = StreamIterator<dynamic>(ws);
    ws.add('hello');
    expect(await got.moveNext(), isTrue);
    expect(got.current, 'hello');
    ws.add(<int>[1, 2, 3]);
    expect(await got.moveNext(), isTrue);
    expect(got.current, isA<Uint8List>());
    expect(got.current, <int>[1, 2, 3]);
    await ws.close(WebSocketStatus.normalClosure, 'done');
    await accepted.single.done;
    expect(accepted.single.closeCode, WebSocketStatus.normalClosure);
    expect(accepted.single.closeReason, 'done');
    expect(accepted.single.readyState, WebSocket.closed);
  });

  test('a message over maxMessageSize closes with 1009', () async {
    WebSocket ws = await WebSocket.connect(url('/ws'));
    ws.add('12345678901');
    await ws.drain<void>();
    expect(ws.closeCode, WebSocketStatus.messageTooBig);
    await accepted.single.done;
    expect(accepted.single.closeCode, WebSocketStatus.messageTooBig);
  });

  test('answers with the subprotocol and never with compression', () async {
    // the dart:io client asks for permessage-deflate by default
    WebSocket ws = await WebSocket.connect(
      url('/proto'),
      protocols: <String>['chat'],
    );
    expect(ws.protocol, 'chat');
    expect(ws.extensions, isEmpty);
    await ws.close();
  });

  test('the server closes with a code and reason', () async {
    WebSocket ws = await WebSocket.connect(url('/bye'));
    await ws.drain<void>();
    expect(ws.closeCode, 4000);
    expect(ws.closeReason, 'bye');
    await accepted.single.done;
    expect(accepted.single.closeCode, 4000);
  });

  test('a refused upgrade is a normal answer', () async {
    await expectLater(
      WebSocket.connect(url('/no')),
      throwsA(isA<WebSocketException>()),
    );
    HttpClient client = HttpClient();
    HttpClientResponse res = await (await client.get(
      '127.0.0.1',
      server.port,
      '/no',
    )).close();
    expect(res.statusCode, HttpStatus.forbidden);
    client.close(force: true);
  });

  test('a request that is no upgrade gets 400', () async {
    HttpClient client = HttpClient();
    HttpClientResponse res = await (await client.get(
      '127.0.0.1',
      server.port,
      '/ws',
    )).close();
    expect(res.statusCode, HttpStatus.badRequest);
    client.close(force: true);
  });

  test('a graceful close sends 1001 to open sockets', () async {
    WebSocket ws = await WebSocket.connect(url('/ws'));
    StreamIterator<dynamic> got = StreamIterator<dynamic>(ws);
    ws.add('ping');
    expect(await got.moveNext(), isTrue);
    Future<void> closing = server.close();
    expect(await got.moveNext(), isFalse);
    await closing;
    expect(ws.closeCode, WebSocketStatus.goingAway);
    expect(accepted.single.closeCode, WebSocketStatus.goingAway);
  });
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dox_socketio/dox_socketio.dart';
import 'package:test/test.dart';

/// Checks for the fixes of the security review.
void main() {
  SocketIoServer? io;
  late HttpServer http;
  List<String> connected = <String>[];

  String wsUrl() =>
      'ws://127.0.0.1:${http.port}/socket.io/?EIO=4&transport=websocket';

  Future<void> start(ServerOptions options, [Middleware? middleware]) async {
    connected.clear();
    SocketIoServer server = SocketIoServer(options: options);
    io = server;
    if (middleware != null) server.use(middleware);
    server.on('connection', (Socket socket) => connected.add(socket.id));
    http = await server.listen(0);
  }

  /// Opens a raw websocket and reads the open packet.
  Future<StreamIterator<dynamic>> open(WebSocket ws) async {
    StreamIterator<dynamic> frames = StreamIterator<dynamic>(ws);
    await frames.moveNext();
    return frames;
  }

  tearDown(() async {
    await io?.close();
    io = null;
  });

  test('deeply nested binary packet is a parse error', () {
    SocketDecoder decoder = SocketDecoder();
    String deep = '${'[' * 100}1${']' * 100}';
    decoder.add('51-["e",$deep]');
    expect(
      () => decoder.add(Uint8List.fromList(<int>[1])),
      throwsFormatException,
    );
  });

  test('many CONNECT packets at once make one socket', () async {
    await start(
      ServerOptions(),
      (Socket s) => Future<void>.delayed(Duration(milliseconds: 100)),
    );
    WebSocket ws = await WebSocket.connect(wsUrl());
    await open(ws);
    for (int i = 0; i < 5; i++) {
      ws.add('40');
    }
    await Future<void>.delayed(Duration(milliseconds: 300));
    expect(connected, hasLength(1));
    await ws.close();
  });

  test('websocket compression is off', () async {
    await start(ServerOptions());
    HttpClient client = HttpClient();
    HttpClientRequest req = await client.getUrl(
      Uri.parse(wsUrl().replaceFirst('ws:', 'http:')),
    );
    req.headers
      ..set('connection', 'Upgrade')
      ..set('upgrade', 'websocket')
      ..set('sec-websocket-key', 'dGhlIHNhbXBsZSBub25jZQ==')
      ..set('sec-websocket-version', '13')
      ..set('sec-websocket-extensions', 'permessage-deflate');
    HttpClientResponse res = await req.close();
    expect(res.statusCode, HttpStatus.switchingProtocols);
    expect(res.headers.value('sec-websocket-extensions'), isNull);
    (await res.detachSocket()).destroy();
    client.close(force: true);
  });

  test('websocket from an origin not in the list gets 403', () async {
    await start(
      ServerOptions(
        cors: CorsOptions(origins: <String>['http://allowed.test']),
      ),
    );
    await expectLater(
      WebSocket.connect(
        wsUrl(),
        headers: <String, String>{'origin': 'http://evil.test'},
      ),
      throwsA(isA<WebSocketException>()),
    );
    WebSocket ok = await WebSocket.connect(
      wsUrl(),
      headers: <String, String>{'origin': 'http://allowed.test'},
    );
    await ok.close();
  });

  test('"*" origin with credentials throws', () {
    expect(
      () => SocketIoServer(
        options: ServerOptions(cors: CorsOptions(credentials: true)),
      ),
      throwsArgumentError,
    );
  });

  test('middleware error text is not sent to the client', () async {
    await start(
      ServerOptions(),
      (Socket s) => throw StateError('SELECT * FROM secret'),
    );
    WebSocket ws = await WebSocket.connect(wsUrl());
    StreamIterator<dynamic> frames = await open(ws);
    ws.add('40');
    await frames.moveNext();
    expect(frames.current, '44{"message":"Internal error"}');
    await ws.close();
  });

  test('a refused client is closed after connectTimeout', () async {
    await start(
      ServerOptions(connectTimeout: Duration(milliseconds: 200)),
      (Socket s) => throw SocketIoException('no'),
    );
    WebSocket ws = await WebSocket.connect(wsUrl());
    StreamIterator<dynamic> frames = await open(ws);
    ws.add('40');
    // The stream ends when the server closes the socket.
    bool closed = await Future<bool>(() async {
      while (await frames.moveNext()) {}
      return true;
    }).timeout(Duration(seconds: 2), onTimeout: () => false);
    expect(closed, isTrue);
  });
}

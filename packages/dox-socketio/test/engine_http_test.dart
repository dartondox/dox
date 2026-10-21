import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dox_socketio/dox_socketio.dart';
import 'package:test/test.dart';

/// Raw HTTP and websocket checks of the Engine.IO layer.
void main() {
  late SocketIoServer io;
  late HttpServer http;
  late HttpClient client;
  List<String> reasons = <String>[];

  String base() => 'http://127.0.0.1:${http.port}/socket.io/';

  Future<(int, String, HttpHeaders)> request(
    String method,
    String query, {
    String? body,
    Map<String, String> headers = const <String, String>{},
  }) async {
    HttpClientRequest req = await client.openUrl(
      method,
      Uri.parse('${base()}?$query'),
    );
    headers.forEach(req.headers.set);
    if (body != null) req.write(body);
    HttpClientResponse res = await req.close();
    String text = await utf8.decodeStream(res);
    return (res.statusCode, text, res.headers);
  }

  Future<String> handshake() async {
    (int, String, HttpHeaders) res = await request(
      'GET',
      'EIO=4&transport=polling',
    );
    return (jsonDecode(res.$2.substring(1)) as Map<String, dynamic>)['sid']
        as String;
  }

  setUp(() async {
    reasons.clear();
    io = SocketIoServer(
      options: ServerOptions(
        pingInterval: Duration(milliseconds: 200),
        pingTimeout: Duration(milliseconds: 200),
        maxHttpBufferSize: 100,
        cors: CorsOptions(
          origins: <String>['http://allowed.test'],
          credentials: true,
        ),
      ),
    );
    io.on('connection', (Socket socket) {
      socket.on(
        'disconnect',
        (SocketEvent e) => reasons.add(e.data! as String),
      );
      socket.on('ask', (SocketEvent e) async {
        try {
          await socket.emitWithAck(
            'q',
            1,
            timeout: Duration(milliseconds: 100),
          );
        } on TimeoutException {
          socket.emit('timed-out');
        }
      });
    });
    http = await io.listen(0);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await io.close();
  });

  test('polling handshake sends the open packet', () async {
    (int, String, HttpHeaders) res = await request(
      'GET',
      'EIO=4&transport=polling',
    );
    expect(res.$1, 200);
    expect(res.$2[0], '0');
    Map<String, dynamic> open =
        jsonDecode(res.$2.substring(1)) as Map<String, dynamic>;
    expect(open['upgrades'], <String>['websocket']);
    expect(open['pingInterval'], 200);
    expect(open['pingTimeout'], 200);
    expect(open['maxPayload'], 100);
    expect((open['sid'] as String).length, 20);
  });

  test('errors use Engine.IO codes', () async {
    (int, String, HttpHeaders) res = await request(
      'GET',
      'EIO=3&transport=polling',
    );
    expect(res.$1, 400);
    expect(jsonDecode(res.$2), <String, Object>{
      'code': 5,
      'message': 'Unsupported protocol version',
    });
    res = await request('GET', 'EIO=4&transport=carrier-pigeon');
    expect((jsonDecode(res.$2) as Map<String, dynamic>)['code'], 0);
    res = await request('GET', 'EIO=4&transport=polling&sid=nope');
    expect((jsonDecode(res.$2) as Map<String, dynamic>)['code'], 1);
    res = await request('POST', 'EIO=4&transport=polling', body: '40');
    expect((jsonDecode(res.$2) as Map<String, dynamic>)['code'], 2);
    res = await request('GET', 'EIO=4&transport=websocket');
    expect((jsonDecode(res.$2) as Map<String, dynamic>)['code'], 3);
  });

  test('other paths get 404', () async {
    HttpClientRequest req = await client.getUrl(
      Uri.parse('http://127.0.0.1:${http.port}/other'),
    );
    HttpClientResponse res = await req.close();
    await res.drain<void>();
    expect(res.statusCode, 404);
  });

  test('CORS headers and preflight', () async {
    (int, String, HttpHeaders) res = await request(
      'OPTIONS',
      'EIO=4&transport=polling',
      headers: <String, String>{
        'origin': 'http://allowed.test',
        'access-control-request-headers': 'x-token',
      },
    );
    expect(res.$1, 204);
    expect(res.$3.value('access-control-allow-origin'), 'http://allowed.test');
    expect(res.$3.value('access-control-allow-credentials'), 'true');
    expect(res.$3.value('access-control-allow-headers'), 'x-token');
    res = await request(
      'GET',
      'EIO=4&transport=polling',
      headers: <String, String>{'origin': 'http://evil.test'},
    );
    expect(res.$3.value('access-control-allow-origin'), isNull);
  });

  test('polling: connect, message, ping/pong and close', () async {
    String sid = await handshake();
    String query = 'EIO=4&transport=polling&sid=$sid';
    (int, String, HttpHeaders) post = await request('POST', query, body: '40');
    expect(post.$2, 'ok');
    (int, String, HttpHeaders) poll = await request('GET', query);
    expect(poll.$2, startsWith('40{"sid":"'));
    // The next poll waits for the server ping.
    poll = await request('GET', query);
    expect(poll.$2, '2');
    await request('POST', query, body: '3');
    // Client close packet.
    await request('POST', query, body: '1');
    await Future<void>.delayed(Duration(milliseconds: 50));
    expect(reasons, <String>['transport close']);
  });

  test('polling: body bigger than maxHttpBufferSize is refused', () async {
    String sid = await handshake();
    (int, String, HttpHeaders) res = await request(
      'POST',
      'EIO=4&transport=polling&sid=$sid',
      body: '4${'x' * 200}',
    );
    expect(res.$1, 413);
    res = await request('GET', 'EIO=4&transport=polling&sid=$sid');
    expect(res.$1, 400);
  });

  test('websocket: no pong means ping timeout', () async {
    WebSocket ws = await WebSocket.connect(
      'ws://127.0.0.1:${http.port}/socket.io/?EIO=4&transport=websocket',
    );
    StreamIterator<dynamic> frames = StreamIterator<dynamic>(ws);
    expect(await frames.moveNext(), isTrue);
    expect(frames.current as String, startsWith('0{'));
    ws.add('40');
    expect(await frames.moveNext(), isTrue);
    expect(frames.current as String, startsWith('40{"sid"'));
    expect(await frames.moveNext(), isTrue);
    expect(frames.current, '2');
    // Do not answer. The server closes the socket.
    while (await frames.moveNext()) {}
    expect(reasons, <String>['ping timeout']);
  });

  test('websocket: bad packet closes with parse error', () async {
    WebSocket ws = await WebSocket.connect(
      'ws://127.0.0.1:${http.port}/socket.io/?EIO=4&transport=websocket',
    );
    StreamIterator<dynamic> frames = StreamIterator<dynamic>(ws);
    await frames.moveNext();
    ws.add('40');
    await frames.moveNext();
    ws.add('42{"not":"an array"}');
    while (await frames.moveNext()) {}
    expect(reasons, <String>['parse error']);
  });

  test('server ack times out', () async {
    WebSocket ws = await WebSocket.connect(
      'ws://127.0.0.1:${http.port}/socket.io/?EIO=4&transport=websocket',
    );
    StreamIterator<dynamic> frames = StreamIterator<dynamic>(ws);
    await frames.moveNext();
    ws.add('40');
    await frames.moveNext();
    ws.add('42["ask"]');
    List<String> seen = <String>[];
    while (await frames.moveNext()) {
      String frame = frames.current as String;
      seen.add(frame);
      if (frame == '2') ws.add('3');
      if (frame == '42["timed-out"]') break;
    }
    expect(seen, contains('420["q",1]'));
    await ws.close();
  });
}

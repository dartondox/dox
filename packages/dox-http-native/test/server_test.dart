import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

/// test app: `/` hello, `/echo` the body back, `/who` the isolate name,
/// `/headers` some request data as json, anything else 404.
void handle(HttpRequest req) async {
  HttpResponse res = req.response;
  switch (req.uri.path) {
    case '/':
      res.write('Hello World');
    case '/echo':
      List<int> body = <int>[for (List<int> c in await req.toList()) ...c];
      res.headers.contentType = ContentType.binary;
      res.add(body);
    case '/who':
      res.write(Isolate.current.debugName);
    case '/headers':
      res.headers.contentType = ContentType.json;
      res.cookies.add(Cookie('a', 'b'));
      res.write(
        jsonEncode(<String, dynamic>{
          'method': req.method,
          'query': req.uri.queryParameters,
          'x': req.headers.value('x-test'),
          'ip': req.connectionInfo?.remoteAddress.address,
          'cookie': req.cookies
              .map((Cookie c) => '${c.name}=${c.value}')
              .join(),
        }),
      );
    default:
      res.statusCode = HttpStatus.notFound;
      res.write('not found');
  }
  await res.close();
}

Future<NativeHttpServer> start(int port, {int maxBodySize = 1024}) async {
  NativeHttpServer server = await NativeHttpServer.bind(
    port,
    maxBodySize: maxBodySize,
  );
  server.listen(handle);
  return server;
}

/// send raw bytes, read until the server closes or [wait] passes.
Future<String> raw(int port, String request, {Duration? wait}) async {
  Socket socket = await Socket.connect('127.0.0.1', port);
  socket.write(request);
  await socket.flush();
  StringBuffer out = StringBuffer();
  Completer<void> done = Completer<void>();
  socket.listen(
    (List<int> data) => out.write(latin1.decode(data)),
    onDone: () {
      if (!done.isCompleted) done.complete();
    },
    onError: (Object _) {
      if (!done.isCompleted) done.complete();
    },
  );
  await done.future.timeout(
    wait ?? const Duration(seconds: 5),
    onTimeout: () {},
  );
  socket.destroy();
  return out.toString();
}

void spawned(List<Object> args) async {
  SendPort ready = args[1] as SendPort;
  await start(args[0] as int);
  ready.send(true);
}

void main() {
  late NativeHttpServer server;
  late int port;
  HttpClient client = HttpClient();

  Future<(int, String)> get(String path, {Map<String, String>? headers}) async {
    HttpClientRequest req = await client.get('127.0.0.1', port, path);
    headers?.forEach(req.headers.set);
    HttpClientResponse res = await req.close();
    return (res.statusCode, await utf8.decodeStream(res));
  }

  setUpAll(() async {
    expect(NativeHttpServer.loadError, isNull);
    server = await start(0);
    port = server.port;
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close();
  });

  test('GET', () async {
    HttpClientRequest req = await client.get('127.0.0.1', port, '/');
    HttpClientResponse res = await req.close();
    expect(res.statusCode, 200);
    expect(res.headers.contentType?.mimeType, 'text/plain');
    expect(res.headers.value('x-content-type-options'), 'nosniff');
    expect(await utf8.decodeStream(res), 'Hello World');
  });

  test('request data: method, query, headers, ip, cookies', () async {
    (int, String) res = await get(
      '/headers?a=1&b=two',
      headers: <String, String>{'x-test': 'yes', 'cookie': 'k=v'},
    );
    expect(res.$1, 200);
    expect(jsonDecode(res.$2), <String, dynamic>{
      'method': 'GET',
      'query': <String, dynamic>{'a': '1', 'b': 'two'},
      'x': 'yes',
      'ip': anyOf('127.0.0.1', '::ffff:127.0.0.1'),
      'cookie': 'k=v',
    });
  });

  test('POST body comes back the same', () async {
    List<int> body = List<int>.generate(1000, (int i) => i % 256);
    HttpClientRequest req = await client.post('127.0.0.1', port, '/echo');
    req.add(body);
    HttpClientResponse res = await req.close();
    expect(res.statusCode, 200);
    expect(<int>[for (List<int> c in await res.toList()) ...c], body);
  });

  test('404', () async {
    expect(await get('/nope'), (404, 'not found'));
  });

  test('keep-alive and pipelining: 3 answers on one connection', () async {
    String out = await raw(
      port,
      'GET / HTTP/1.1\r\nHost: a\r\n\r\n'
      'GET /nope HTTP/1.1\r\nHost: a\r\n\r\n'
      'GET / HTTP/1.1\r\nHost: a\r\nConnection: close\r\n\r\n',
    );
    expect(
      RegExp(r'HTTP/1.1 (\d+)').allMatches(out).map((Match m) => m[1]),
      <String>['200', '404', '200'],
    );
  });

  test('400 for garbage', () async {
    String out = await raw(port, 'HELLO\r\n\r\n');
    expect(out, startsWith('HTTP/1.1 400'));
  });

  test('431 for headers that are too large', () async {
    String big = 'a' * 20000;
    String out = await raw(
      port,
      'GET / HTTP/1.1\r\nHost: a\r\nX-Big: $big\r\n\r\n',
    );
    expect(out, startsWith('HTTP/1.1 431'));
  });

  test('413 for a body over the limit, with and without length', () async {
    HttpClientRequest req = await client.post('127.0.0.1', port, '/echo');
    req.add(List<int>.filled(5000, 1));
    expect((await req.close()).statusCode, 413);

    HttpClientRequest chunked = await client.post('127.0.0.1', port, '/echo');
    chunked.contentLength = -1;
    chunked.add(List<int>.filled(5000, 1));
    expect((await chunked.close()).statusCode, 413);
  });

  test('a large body and response (5 MB)', () async {
    NativeHttpServer big = await start(0, maxBodySize: 10 << 20);
    List<int> body = List<int>.generate(5 << 20, (int i) => i % 251);
    HttpClientRequest req = await client.post('127.0.0.1', big.port, '/echo');
    req.add(body);
    HttpClientResponse res = await req.close();
    List<int> back = <int>[for (List<int> c in await res.toList()) ...c];
    expect(back.length, body.length);
    expect(back, body);
    await big.close();
  });

  test('close frees the port', () async {
    NativeHttpServer a = await start(0);
    int p = a.port;
    await a.close();
    NativeHttpServer b = await start(p);
    expect(b.port, p);
    await b.close();
  });

  test('many isolates on one port share the connections', () async {
    NativeHttpServer main = await start(0);
    int shared = main.port;
    List<Isolate> isolates = <Isolate>[];
    for (int i = 0; i < 3; i++) {
      ReceivePort ready = ReceivePort();
      isolates.add(
        await Isolate.spawn(spawned, <Object>[
          shared,
          ready.sendPort,
        ], debugName: 'worker$i'),
      );
      await ready.first;
    }
    Set<String> seen = <String>{};
    for (int round = 0; round < 10 && seen.length < 2; round++) {
      List<Future<String>> calls = <Future<String>>[
        for (int i = 0; i < 50; i++)
          raw(
            shared,
            'GET /who HTTP/1.1\r\nHost: a\r\nConnection: close\r\n\r\n',
          ),
      ];
      for (String out in await Future.wait(calls)) {
        expect(out, startsWith('HTTP/1.1 200'));
        seen.add(out.split('\r\n\r\n').last);
      }
    }
    expect(seen.length, greaterThan(1));

    // a killed isolate stops its server, the others keep the port
    for (Isolate isolate in isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    int ok = 0;
    for (int i = 0; i < 20; i++) {
      String out = await raw(
        shared,
        'GET / HTTP/1.1\r\nHost: a\r\nConnection: close\r\n\r\n',
        wait: const Duration(seconds: 2),
      );
      if (out.startsWith('HTTP/1.1 200')) ok++;
    }
    expect(ok, greaterThanOrEqualTo(17)); // the first ones may hit a dead one
    await main.close();
  });
}

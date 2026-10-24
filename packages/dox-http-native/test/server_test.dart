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
    case '/slow':
      await Future<void>.delayed(const Duration(milliseconds: 500));
      res.write('slow done');
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
    case '/bad-cookie':
      res.cookies.add(Cookie('a', 'b')..domain = 'x\r\nset-cookie: c=d');
      try {
        await res.close();
      } on FormatException {
        res.cookies.clear();
        res.write('refused');
      }
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

  test('a line break in a cookie domain or server header is refused', () async {
    expect(await get('/bad-cookie'), (200, 'refused'));
    expect(() => server.serverHeader = 'a\nb', throwsFormatException);
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

  test('multipart limit, 413 and idle body timeout', () async {
    NativeHttpServer small = await NativeHttpServer.bind(
      0,
      maxBodySize: 10,
      maxMultipartSize: 100,
      bodyTimeout: const Duration(milliseconds: 200),
    );
    small.listen(handle);
    String body = 'a' * 50;
    String post(String type, int length) =>
        'POST /echo HTTP/1.1\r\nHost: a\r\nConnection: close\r\n'
        'Content-Type: $type\r\nContent-Length: $length\r\n\r\n';
    String form = await raw(
      small.port,
      '${post('multipart/form-data', 50)}$body',
    );
    expect(form, startsWith('HTTP/1.1 200'));
    String json = await raw(small.port, '${post('application/json', 50)}$body');
    expect(json, startsWith('HTTP/1.1 413'));
    // "Expect: 100-continue": the 413 comes before the body is sent
    String early = await raw(
      small.port,
      post(
        'application/json',
        1 << 30,
      ).replaceFirst('Host: a\r\n', 'Host: a\r\nExpect: 100-continue\r\n'),
    );
    expect(early, startsWith('HTTP/1.1 413'));
    // a full body over the limit with HttpClient: 413, not a reset
    HttpClientRequest req = await client.post('127.0.0.1', small.port, '/');
    req.add(List<int>.filled(1 << 20, 1));
    expect((await req.close()).statusCode, 413);
    // slow but steady: 500 ms in all, never 200 ms without bytes
    Socket steady = await Socket.connect('127.0.0.1', small.port);
    steady.write(post('text/plain', 5));
    for (int i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      steady.write('a');
      await steady.flush();
    }
    String out = latin1.decode(<int>[
      for (List<int> c in await steady.toList()) ...c,
    ]);
    steady.destroy();
    expect(out, startsWith('HTTP/1.1 200'));
    // stalled: no more bytes, 408 after 200 ms
    String slow = await raw(small.port, '${post('text/plain', 5)}ab');
    expect(slow, startsWith('HTTP/1.1 408'));
    await small.close();
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

  test('HEAD gets the headers with no body', () async {
    String out = await raw(
      port,
      'HEAD / HTTP/1.1\r\nHost: a\r\nConnection: close\r\n\r\n',
    );
    expect(out, startsWith('HTTP/1.1 200'));
    expect(out.toLowerCase(), contains('content-length: 11'));
    expect(out, endsWith('\r\n\r\n'));
  });

  test('bind to one host only', () async {
    NativeHttpServer local = await NativeHttpServer.bind(
      0,
      address: InternetAddress.loopbackIPv4,
    );
    local.listen(handle);
    expect(local.address, InternetAddress.loopbackIPv4);
    HttpClientResponse res = await (await client.get(
      '127.0.0.1',
      local.port,
      '/',
    )).close();
    expect(res.statusCode, 200);
    await res.drain<void>();
    // not on the IPv6 loopback
    await expectLater(
      Socket.connect(InternetAddress.loopbackIPv6, local.port),
      throwsA(isA<SocketException>()),
    );
    await local.close();

    NativeHttpServer named = await NativeHttpServer.bind(
      0,
      address: 'localhost',
    );
    expect(named.address.isLoopback, isTrue);
    await named.close();
  });

  test('close() lets open requests finish, then frees the port', () async {
    NativeHttpServer a = await start(0);
    int p = a.port;
    HttpClient c = HttpClient();
    Future<String> slow = c
        .get('127.0.0.1', p, '/slow')
        .then((HttpClientRequest r) => r.close())
        .then((HttpClientResponse r) => utf8.decodeStream(r));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    Stopwatch clock = Stopwatch()..start();
    Future<void> closed = a.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // no new connections while it drains
    await expectLater(
      Socket.connect('127.0.0.1', p),
      throwsA(isA<SocketException>()),
    );
    expect(await slow, 'slow done');
    await closed;
    expect(clock.elapsedMilliseconds, greaterThan(200));
    c.close(force: true);
    NativeHttpServer b = await start(p);
    expect(b.port, p);
    await b.close();
  });

  test('close(force: true) cuts open requests', () async {
    NativeHttpServer a = await start(0);
    HttpClient c = HttpClient();
    Future<Object> slow = c
        .get('127.0.0.1', a.port, '/slow')
        .then((HttpClientRequest r) => r.close())
        .then<Object>((HttpClientResponse r) => utf8.decodeStream(r))
        .catchError((Object error) => error);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    Future<void> graceful = a.close();
    await a.close(force: true);
    await graceful; // a waiting graceful close ends too
    expect(await slow, isA<Exception>());
    c.close(force: true);
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

    // a killed isolate stops its server (the idle probe finds it within
    // 100 ms), the others keep the port. no request may be lost after that.
    for (Isolate isolate in isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    int ok = 0;
    for (int i = 0; i < 20; i++) {
      String out = await raw(
        shared,
        'GET / HTTP/1.1\r\nHost: a\r\nConnection: close\r\n\r\n',
        wait: const Duration(seconds: 2),
      );
      if (out.startsWith('HTTP/1.1 200')) ok++;
    }
    expect(ok, 20);
    await main.close();
  });
}

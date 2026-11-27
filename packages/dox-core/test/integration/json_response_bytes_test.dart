import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart' show jsonBytesLent;
import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

import '../dtos/dtos.dart';
import '../dtos/response.dto.dart';
import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

/// A JSON response of the native server uses the bytes of the encoder
/// with no copy. These tests make sure that one response never gets the
/// bytes of another one.
AppConfig _config({bool compress = false, bool sdkEncoder = false}) {
  return AppConfig(
    appKey: testAppKey,
    // the OS picks a free port, so test files can run in parallel
    serverPort: 0,
    totalIsolate: 1,
    compress: compress,
    dtos: testDtos,
    flags: CoreFlags(sdkJsonEncoder: sdkEncoder),
  );
}

class _NoToJson {}

/// A body that is different for each [n], from 20 bytes to 60 kB.
Map<String, dynamic> _item(int n) {
  return <String, dynamic>{
    'id': n,
    'name': 'item $n é 日本 မြန်မာစာ 😀 👨‍👩‍👧‍👦',
    'tags': List<String>.generate(n % 7, (int i) => 'tag-$n-$i'),
    'text': 'x$n' * ((n * 37) % 15000),
  };
}

ProductView _product(int id) {
  return ProductView(
    id: id,
    productName: 'product $id',
    price: id / 2,
    inStock: true,
    soldAt: DateTime.utc(2024, 5, id),
  );
}

/// The server calls toString() of a cookie after it took the body and
/// before it copies it. This one encodes JSON there.
class _EncodingCookie implements Cookie {
  _EncodingCookie(this.n);
  final int n;

  @override
  String name = 'k';
  @override
  String value = 'v';
  @override
  DateTime? expires;
  @override
  int? maxAge;
  @override
  String? domain;
  @override
  String? path;
  @override
  bool secure = false;
  @override
  bool httpOnly = false;
  @override
  SameSite? sameSite;

  @override
  String toString() {
    JSON.bytes(_item(n + 1000));
    JSON.stringify(_item(n + 2000));
    return 'k$n=v$n';
  }
}

/// Encodes JSON while its own JSON is encoded.
class _Reenter {
  _Reenter(this.n);
  final int n;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'bytes': JSON.bytes(_item(n + 3000)).length,
      'text': JSON.stringify(<int>[n, n + 1]),
    };
  }
}

Map<String, dynamic> _reenter(int n) {
  return <String, dynamic>{'outer': n, 'inner': _Reenter(n)};
}

/// One route of the mix: its path for [n], and the body it must give.
/// A null body is not checked (an error answer).
typedef _Case = (String path, String? body, int status);

_Case _case(int kind, int n) {
  return switch (kind) {
    0 => ('/item/$n', JSON.stringify(_item(n)), 200),
    1 => ('/slow/$n', JSON.stringify(_item(n)), 200),
    2 => ('/cookie/$n', JSON.stringify(_item(n)), 200),
    3 => ('/reenter/$n', JSON.stringify(_reenter(n)), 200),
    4 => ('/text/$n', 'text $n ${'é' * (n % 40)}', 200),
    5 => ('/status/$n', JSON.stringify(_item(n)), 201),
    6 => ('/dto', JSON.stringify(_product(1)), 200),
    7 => ('/stream/$n', 'part-$n;' * (n % 20 + 1), 200),
    _ => ('/throw/$n', null, 500),
  };
}

Future<(int, String)> _fetch(
  HttpClient client,
  String path, {
  String method = 'GET',
}) async {
  HttpClientRequest req = await client.open(
    method,
    '127.0.0.1',
    Dox().server.httpServer.port,
    path,
  );
  HttpClientResponse res = await req.close();
  String body = utf8.decode(await res.fold(<int>[], _join));
  return (res.statusCode, body);
}

Future<String> _get(HttpClient client, String path) async {
  return (await _fetch(client, path)).$2;
}

List<int> _join(List<int> all, List<int> part) => all..addAll(part);

void _routes() {
  Route.get('/item/{n}', (DoxRequest req) {
    return _item(int.parse('${req.param['n']}'));
  });
  // the handler waits, so other requests run before its response
  Route.get('/slow/{n}', (DoxRequest req) async {
    int n = int.parse('${req.param['n']}');
    await Future<void>.delayed(Duration(milliseconds: n % 5));
    return _item(n);
  });
  Route.get('/cookie/{n}', (DoxRequest req) {
    int n = int.parse('${req.param['n']}');
    req.httpRequest.response.cookies.add(_EncodingCookie(n));
    return _item(n);
  });
  Route.get('/reenter/{n}', (DoxRequest req) {
    return _reenter(int.parse('${req.param['n']}'));
  });
  Route.get('/text/{n}', (DoxRequest req) {
    int n = int.parse('${req.param['n']}');
    return 'text $n ${'é' * (n % 40)}';
  });
  Route.get('/status/{n}', (DoxRequest req) {
    int n = int.parse('${req.param['n']}');
    return response(_item(n)).statusCode(201).header('X-N', '$n');
  });
  Route.get('/stream/{n}', (DoxRequest req) {
    int n = int.parse('${req.param['n']}');
    return Stream<List<int>>.fromIterable(<List<int>>[
      for (int i = 0; i <= n % 20; i++) utf8.encode('part-$n;'),
    ]);
  });
  Route.get('/throw/{n}', (DoxRequest req) async {
    await Future<void>.delayed(Duration.zero);
    throw StateError('boom ${req.param['n']}');
  });
  // a line break in the domain: the server refuses the cookie in end()
  Route.get('/bad-cookie/{n}', (DoxRequest req) {
    req.httpRequest.response.cookies.add(Cookie('a', 'b')..domain = 'x\r\ny');
    return _item(int.parse('${req.param['n']}'));
  });
  // the head goes out first: the JSON body then goes out in parts
  Route.get('/flushed/{n}', (DoxRequest req) async {
    await req.httpRequest.response.flush();
    return _item(int.parse('${req.param['n']}'));
  });
  Route.get('/lent', (DoxRequest req) {
    return <String, bool>{'lent': jsonBytesLent};
  });
  Route.get('/bad', (DoxRequest req) {
    return <String, dynamic>{'ok': true, 'bad': _NoToJson()};
  });
  Route.get('/dto', (DoxRequest req) {
    return _product(1);
  });
  Route.get('/dtos', (DoxRequest req) {
    return <ProductView>[_product(1), _product(2)];
  });
  Route.get('/huge', (DoxRequest req) {
    return <String, dynamic>{'text': 'é' * (1 << 20)};
  });
}

/// The encoder buffer must not stay lent after the responses ended.
Future<void> _nothingLent(HttpClient client) async {
  expect(await _get(client, '/lent'), '{"lent":false}');
}

Future<void> _manyAtOnce() async {
  HttpClient client = HttpClient()..maxConnectionsPerHost = 16;
  List<Future<String>> bodies = <Future<String>>[
    for (int n = 0; n < 300; n++)
      _get(client, n.isEven ? '/item/$n' : '/slow/$n'),
  ];
  List<String> got = await Future.wait(bodies);
  for (int n = 0; n < 300; n++) {
    expect(got[n], JSON.stringify(_item(n)), reason: 'item $n');
  }
  client.close();
}

/// [count] requests of every kind of the mix, at the same time, in a
/// random order.
Future<void> _mix(int count, int seed) async {
  Random random = Random(seed);
  HttpClient client = HttpClient()..maxConnectionsPerHost = 32;
  List<_Case> cases = <_Case>[
    for (int i = 0; i < count; i++)
      _case(random.nextInt(9), random.nextInt(400)),
  ];
  List<(int, String)> got = await Future.wait(<Future<(int, String)>>[
    for (_Case c in cases) _fetch(client, c.$1),
  ]);
  for (int i = 0; i < count; i++) {
    _Case c = cases[i];
    expect(got[i].$1, c.$3, reason: c.$1);
    if (c.$2 != null) expect(got[i].$2, c.$2, reason: c.$1);
  }
  await _nothingLent(client);
  client.close();
}

/// Reads [count] HTTP/1.1 answers with a content-length from [socket].
Future<List<(int, String)>> _readAnswers(Socket socket, int count) async {
  List<(int, String)> answers = <(int, String)>[];
  BytesBuilder data = BytesBuilder(copy: false);
  Completer<void> done = Completer<void>();
  late StreamSubscription<Uint8List> sub;
  sub = socket.listen(
    (Uint8List part) {
      data.add(part);
      Uint8List all = data.toBytes();
      int at = 0;
      while (answers.length < count) {
        int end = _indexOf(all, '\r\n\r\n'.codeUnits, at);
        if (end < 0) break;
        String head = latin1.decode(all.sublist(at, end));
        int length = int.parse(
          RegExp(
            r'content-length: *(\d+)',
            caseSensitive: false,
          ).firstMatch(head)!.group(1)!,
        );
        int bodyStart = end + 4;
        if (all.length < bodyStart + length) break;
        int status = int.parse(head.split(' ')[1]);
        answers.add((
          status,
          utf8.decode(all.sublist(bodyStart, bodyStart + length)),
        ));
        at = bodyStart + length;
      }
      data = BytesBuilder(copy: false)..add(all.sublist(at));
      if (answers.length == count && !done.isCompleted) done.complete();
    },
    onDone: () {
      if (!done.isCompleted) done.complete();
    },
  );
  await done.future.timeout(const Duration(seconds: 30));
  await sub.cancel();
  return answers;
}

int _indexOf(List<int> data, List<int> pattern, int from) {
  for (int i = from; i <= data.length - pattern.length; i++) {
    int j = 0;
    while (j < pattern.length && data[i + j] == pattern[j]) {
      j++;
    }
    if (j == pattern.length) return i;
  }
  return -1;
}

void main() {
  setUp(_routes);

  tearDown(() async {
    await Dox().server.close();
  });

  test('300 responses at the same time, each has its own body', () async {
    await startHttpServer(_config());
    expect(Dox().server.httpServer, isA<NativeHttpServer>());
    await _manyAtOnce();
  });

  test('the same with gzip', () async {
    await startHttpServer(_config(compress: true));
    await _manyAtOnce();
  });

  /// A cookie whose toString() encodes JSON, a toJson() that encodes
  /// JSON, text, a stream, a status, a DTO and an error, all mixed.
  test('1,000 mixed responses at the same time', () async {
    await startHttpServer(_config());
    await _mix(1000, 1);
  });

  test('the same with gzip', () async {
    await startHttpServer(_config(compress: true));
    await _mix(1000, 2);
  });

  test('the same with the encoder of the SDK (sdkJsonEncoder)', () async {
    await startHttpServer(_config(sdkEncoder: true));
    await _mix(1000, 3);
  });

  test('a cookie that encodes JSON in toString()', () async {
    await startHttpServer(_config());
    HttpClient client = HttpClient();
    for (int n = 0; n < 50; n++) {
      HttpClientRequest req = await client.get(
        '127.0.0.1',
        Dox().server.httpServer.port,
        '/cookie/$n',
      );
      HttpClientResponse res = await req.close();
      String body = utf8.decode(await res.fold(<int>[], _join));
      expect(body, JSON.stringify(_item(n)), reason: 'cookie $n');
      expect(res.cookies.single.name, 'k$n');
    }
    await _nothingLent(client);
    client.close();
  });

  /// Many requests in one write on one connection: the answers must come
  /// back in order, each with its own body.
  test('200 requests in one write on one connection', () async {
    await startHttpServer(_config());
    Random random = Random(4);
    List<_Case> cases = <_Case>[
      for (int i = 0; i < 200; i++)
        // no stream: its answer has no content-length
        _case(
          <int>[0, 1, 2, 3, 4, 5, 6][random.nextInt(7)],
          random.nextInt(400),
        ),
    ];
    Socket socket = await Socket.connect(
      '127.0.0.1',
      Dox().server.httpServer.port,
    );
    socket.add(
      utf8.encode(
        <String>[
          for (_Case c in cases) 'GET ${c.$1} HTTP/1.1\r\nHost: x\r\n\r\n',
        ].join(),
      ),
    );
    List<(int, String)> answers = await _readAnswers(socket, cases.length);
    socket.destroy();
    expect(answers.length, cases.length);
    for (int i = 0; i < cases.length; i++) {
      expect(answers[i].$1, cases[i].$3, reason: cases[i].$1);
      expect(answers[i].$2, cases[i].$2, reason: cases[i].$1);
    }
    HttpClient client = HttpClient();
    await _nothingLent(client);
    client.close();
  });

  /// A client that sends a request and leaves before the answer.
  test('clients that leave, between normal ones', () async {
    await startHttpServer(_config());
    int port = Dox().server.httpServer.port;
    HttpClient client = HttpClient()..maxConnectionsPerHost = 16;
    List<Future<void>> all = <Future<void>>[];
    for (int n = 0; n < 300; n++) {
      if (n % 3 == 0) {
        all.add(() async {
          Socket socket = await Socket.connect('127.0.0.1', port);
          socket.add(
            utf8.encode(
              'GET /${n.isEven ? 'slow' : 'cookie'}/$n HTTP/1.1\r\n'
              'Host: x\r\n\r\n',
            ),
          );
          socket.destroy();
        }());
      } else {
        _Case c = _case(n % 4, n);
        all.add(() async {
          expect(await _get(client, c.$1), c.$2, reason: c.$1);
        }());
      }
    }
    await Future.wait(all);
    // the slow handlers of the clients that left end now
    await Future<void>.delayed(const Duration(milliseconds: 50));
    for (int n = 0; n < 20; n++) {
      expect(await _get(client, '/item/$n'), JSON.stringify(_item(n)));
    }
    await _nothingLent(client);
    client.close();
  });

  /// end() throws for a bad cookie, before it copied the body. The
  /// buffer must still be given back. (That request gets no answer: an
  /// old bug of a bad cookie, not of the encoder.)
  test('end() throws: the buffer is given back', () async {
    await startHttpServer(_config());
    int port = Dox().server.httpServer.port;
    for (int n = 0; n < 5; n++) {
      Socket socket = await Socket.connect('127.0.0.1', port);
      socket.add(utf8.encode('GET /bad-cookie/$n HTTP/1.1\r\nHost: x\r\n\r\n'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      socket.destroy();
    }
    HttpClient client = HttpClient();
    await _nothingLent(client);
    expect(await _get(client, '/item/7'), JSON.stringify(_item(7)));
    client.close();
  });

  test('JSON after flush() goes out in parts, with the right body', () async {
    await startHttpServer(_config());
    HttpClient client = HttpClient()..maxConnectionsPerHost = 8;
    List<String> got = await Future.wait(<Future<String>>[
      for (int n = 0; n < 50; n++)
        _get(client, n.isEven ? '/flushed/$n' : '/item/$n'),
    ]);
    for (int n = 0; n < 50; n++) {
      expect(got[n], JSON.stringify(_item(n)), reason: 'item $n');
    }
    await _nothingLent(client);
    client.close();
  });

  test('HEAD answers have no body, then GET is right', () async {
    await startHttpServer(_config());
    HttpClient client = HttpClient();
    for (int n = 0; n < 30; n++) {
      (int, String) head = await _fetch(client, '/item/$n', method: 'HEAD');
      expect(head.$1, 200);
      expect(head.$2, '');
      expect(await _get(client, '/item/$n'), JSON.stringify(_item(n)));
    }
    await _nothingLent(client);
    client.close();
  });

  test('a DTO and a list of DTOs as the response', () async {
    await startHttpServer(_config());
    HttpClient client = HttpClient();
    String one =
        '{"id":1,"product_name":"product 1","price":0.5,"in_stock":true,'
        '"sold_at":"2024-05-01T00:00:00.000Z"}';
    String two =
        '{"id":2,"product_name":"product 2","price":1.0,"in_stock":true,'
        '"sold_at":"2024-05-02T00:00:00.000Z"}';
    expect(await _get(client, '/dto'), one);
    expect(await _get(client, '/dtos'), '[$one,$two]');
    client.close();
  });

  test('a small body after a very large one', () async {
    await startHttpServer(_config());
    HttpClient client = HttpClient();
    String huge = await _get(client, '/huge');
    expect(huge.length, (1 << 20) + 11);
    expect(huge.substring(0, 12), '{"text":"ééé');
    expect(await _get(client, '/item/3'), JSON.stringify(_item(3)));
    client.close();
  });

  test(
    'a body that can not be encoded gives an error, then all is normal',
    () async {
      await startHttpServer(_config());
      HttpClient client = HttpClient();
      HttpClientRequest req = await client.get(
        '127.0.0.1',
        Dox().server.httpServer.port,
        '/bad',
      );
      HttpClientResponse res = await req.close();
      expect(res.statusCode, 500);
      String body = utf8.decode(await res.fold(<int>[], _join));
      // one JSON document: nothing of the body that failed
      expect(JSON.parse(body), isA<Map<String, dynamic>>());
      expect(body.contains('"ok"'), false);
      expect(await _get(client, '/item/5'), JSON.stringify(_item(5)));
      await _nothingLent(client);
      client.close();
    },
  );
}

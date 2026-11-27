import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

/// A JSON response of the native server uses the bytes of the encoder
/// with no copy. These tests make sure that one response never gets the
/// bytes of another one.
AppConfig _config({bool compress = false}) {
  return AppConfig(
    appKey: testAppKey,
    // the OS picks a free port, so test files can run in parallel
    serverPort: 0,
    totalIsolate: 1,
    compress: compress,
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

Future<String> _get(HttpClient client, String path) async {
  HttpClientRequest req = await client.get(
    '127.0.0.1',
    Dox().server.httpServer.port,
    path,
  );
  HttpClientResponse res = await req.close();
  return utf8.decode(await res.fold(<int>[], _join));
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
  Route.get('/bad', (DoxRequest req) {
    return <String, dynamic>{'ok': true, 'bad': _NoToJson()};
  });
  Route.get('/huge', (DoxRequest req) {
    return <String, dynamic>{'text': 'é' * (1 << 20)};
  });
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
      client.close();
    },
  );
}

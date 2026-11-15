import 'dart:io';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:dox_core/session/session_memory_store.dart';
import 'package:test/test.dart';

import '../utils/test_app_key.dart';

/// one GET on a new connection, so the kernel spreads the requests over
/// the isolates (SO_REUSEPORT). Gives the status, the body and the
/// session cookie that came back (or null).
Future<(int, String, Cookie?)> _get(int port, String path, Cookie? c) async {
  HttpClient client = HttpClient();
  HttpClientRequest req = await client.get('127.0.0.1', port, path);
  if (c != null) req.cookies.add(c);
  HttpClientResponse res = await req.close();
  String body = await res.transform(const SystemEncoding().decoder).join();
  client.close(force: true);
  Cookie? cookie;
  for (Cookie k in res.cookies) {
    if (k.name == 'dox_session') cookie = k;
  }
  return (res.statusCode, body, cookie);
}

/// a worker isolate: saves [args] value under a key in the main isolate
/// store, then reads it back
Future<Object?> _putAndGetIn(List<Object> args) async {
  SessionMemoryStore store = SessionMemoryStore.instance
    ..connect(args[0] as SendPort);
  await store.put('memory', 'session:w', <String, dynamic>{
    'name': args[1],
  }, args[2] as Duration);
  Object? value = await store.get('memory', 'session:w');
  store.close();
  return value;
}

Future<Object?> _getIn(SendPort owner) async {
  SessionMemoryStore store = SessionMemoryStore.instance..connect(owner);
  Object? value = await store.get('memory', 'session:w');
  store.close();
  return value;
}

void main() {
  late int port;

  setUpAll(() async {
    ServerSocket probe = await ServerSocket.bind('127.0.0.1', 0);
    port = probe.port;
    await probe.close();
    Dox().initialize(
      AppConfig(
        appKey: testAppKey,
        serverPort: port,
        host: '127.0.0.1',
        totalIsolate: 4,
        session: const SessionConfig(driver: 'cache', store: 'memory'),
        cache: const CacheConfig(
          defaultStore: 'memory',
          stores: <String, Map<String, dynamic>>{
            'memory': <String, dynamic>{'driver': 'memory'},
          },
        ),
      ),
    );
    Route.get('/put', <dynamic>[
      const SessionMiddleware(),
      (DoxRequest req) {
        req.session.put('name', 'ann');
        return 'ok';
      },
    ]);
    Route.get('/get', <dynamic>[
      const SessionMiddleware(),
      (DoxRequest req) => '${Dox().isolateId}:${req.session.get('name')}',
    ]);
    await Dox().startServer();
  });

  tearDownAll(() async {
    DoxIsolate().killAll();
    await Dox().server.close();
  });

  test('a session on a memory store is seen by every isolate', () async {
    expect(DoxIsolate().isolates.length, 3);
    (int, String, Cookie?) put = await _get(port, '/put', null);
    expect(put.$1, 200, reason: put.$2);
    Cookie cookie = put.$3!;
    Set<String> served = <String>{};
    for (int i = 0; i < 40; i++) {
      (int, String, Cookie?) got = await _get(port, '/get', cookie);
      expect(got.$2.split(':').last, 'ann', reason: 'request $i');
      served.add(got.$2.split(':').first);
    }
    // Linux spreads new connections over the isolates (SO_REUSEPORT).
    // macOS sends them all to one isolate, so the check is for Linux only.
    if (Platform.isLinux) {
      expect(served.length, greaterThan(1), reason: 'served by $served');
    }
  });

  test('a worker isolate reads and writes the main isolate store', () async {
    SendPort owner = SessionMemoryStore.instance.port;
    Object? value = await Isolate.run(
      () => _putAndGetIn(<Object>[owner, 'bob', const Duration(minutes: 1)]),
    );
    expect(value, <String, dynamic>{'name': 'bob'});
    // it lives in the memory store of this (main) isolate
    expect(
      await Dox().cache.store('memory').get('session:w'),
      <String, dynamic>{'name': 'bob'},
    );
    expect(await Isolate.run(() => _getIn(owner)), <String, dynamic>{
      'name': 'bob',
    });
  });

  test('an expired session is gone from the main isolate store', () async {
    SendPort owner = SessionMemoryStore.instance.port;
    await Isolate.run(
      () =>
          _putAndGetIn(<Object>[owner, 'cy', const Duration(milliseconds: 50)]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await Isolate.run(() => _getIn(owner)), isNull);
  });
}

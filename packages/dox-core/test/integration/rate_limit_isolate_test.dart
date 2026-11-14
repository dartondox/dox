import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:test/test.dart';

import '../utils/test_app_key.dart';

/// the last second of a 5 minute window
DateTime endOfWindow() => DateTime.utc(2026, 1, 1, 13, 4, 59);

/// the first second of the next window
DateTime startOfNext() => DateTime.utc(2026, 1, 1, 13, 5, 1);

/// sends [times] requests to [path], each on a new connection, so the
/// kernel spreads them over the isolates (SO_REUSEPORT). Gives the
/// count of each status code.
Future<Map<int, int>> _send(int port, String path, int times) async {
  Map<int, int> codes = <int, int>{};
  for (int i = 0; i < times; i++) {
    HttpClient client = HttpClient();
    HttpClientResponse res = await (await client.get(
      '127.0.0.1',
      port,
      path,
    )).close();
    await res.drain<void>();
    client.close(force: true);
    codes[res.statusCode] = (codes[res.statusCode] ?? 0) + 1;
  }
  return codes;
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
        cache: const CacheConfig(
          defaultStore: 'memory',
          stores: <String, Map<String, dynamic>>{
            'memory': <String, dynamic>{'driver': 'memory'},
          },
        ),
      ),
    );
    Route.get('/limited-shared', <dynamic>[
      RateLimit(max: 5, per: const Duration(minutes: 5)),
      (DoxRequest req) => 'ok',
    ]);
    // two routes on one count (same name), with clocks on each side of
    // a window edge
    Route.get('/sliding-end', <dynamic>[
      RateLimit(
        max: 5,
        per: const Duration(minutes: 5),
        name: 'sliding-shared',
        sliding: true,
        now: endOfWindow,
      ),
      (DoxRequest req) => 'ok',
    ]);
    Route.get('/sliding-next', <dynamic>[
      RateLimit(
        max: 5,
        per: const Duration(minutes: 5),
        name: 'sliding-shared',
        sliding: true,
        now: startOfNext,
      ),
      (DoxRequest req) => 'ok',
    ]);
    await Dox().startServer();
  });

  tearDownAll(() async {
    DoxIsolate().killAll();
    await Dox().server.close();
  });

  test('without Redis, max holds across all isolates', () async {
    expect(DoxIsolate().isolates.length, 3);
    int ok = 0;
    int limited = 0;
    for (int i = 0; i < 40; i++) {
      // a new connection each time, so the kernel spreads them over the
      // isolates (SO_REUSEPORT)
      HttpClient client = HttpClient();
      HttpClientResponse res = await (await client.get(
        '127.0.0.1',
        port,
        '/limited-shared',
      )).close();
      await res.drain<void>();
      client.close(force: true);
      if (res.statusCode == 200) ok++;
      if (res.statusCode == 429) limited++;
    }
    expect(ok, 5);
    expect(limited, 35);
  });

  test('sliding: max holds across isolates and over the edge', () async {
    expect(await _send(port, '/sliding-end', 20), <int, int>{200: 5, 429: 15});
    // 20 x 299/300 + 1 is far over 5, so the edge burst is blocked
    expect(await _send(port, '/sliding-next', 10), <int, int>{429: 10});
  });
}

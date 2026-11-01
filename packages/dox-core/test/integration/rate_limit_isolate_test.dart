import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:test/test.dart';

void main() {
  late int port;

  setUpAll(() async {
    ServerSocket probe = await ServerSocket.bind('127.0.0.1', 0);
    port = probe.port;
    await probe.close();
    Dox().initialize(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
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
}

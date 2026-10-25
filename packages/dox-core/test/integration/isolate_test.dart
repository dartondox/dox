import 'dart:io';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/free_port.dart';
import 'requirements/config/api_router.dart';
import 'requirements/handler.dart';

AppConfig isolateConfig(int port) => AppConfig(
  /// application key
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',

  /// a free port, known before the start: all 5 isolates share it.
  /// Port 0 would give each isolate its own port.
  serverPort: port,

  /// total multi-thread isolate to run
  totalIsolate: 1,

  /// response handler
  responseHandler: ResponseHandler(),

  /// routers
  routers: <Router>[ApiRouter()],
);

late String baseUrl;

class ExampleProvider extends DoxProvider {
  @override
  void setup() {}
}

void main() {
  group('Isolate', () {
    setUpAll(() async {
      int port = await freePort();
      baseUrl = 'http://localhost:$port';
      Dox().initialize(isolateConfig(port));
      Dox().addProvider(ExampleProvider());
      Dox().totalIsolate(5);
      await Dox().startServer();
    });

    tearDownAll(() async {
      DoxIsolate().killAll();
      await Dox().server.close();
    });

    test('test', () async {
      Uri url = Uri.parse('$baseUrl/api/ping');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(DoxIsolate().isolates.length, 5 - 1);
    });

    test('dead isolate is started again', () async {
      DoxIsolate().restartDelay = Duration(milliseconds: 10);
      Isolate old = DoxIsolate().isolates[2]!;
      old.kill(priority: Isolate.immediate);

      Isolate? fresh;
      for (int i = 0; i < 100 && fresh == null; i++) {
        await Future<void>.delayed(Duration(milliseconds: 20));
        Isolate? current = DoxIsolate().isolates[2];
        if (current != null && current != old) fresh = current;
      }
      expect(fresh, isNotNull);
      expect(DoxIsolate().isolates.length, 5 - 1);
    });

    test('default isolates is one per cpu core', () {
      expect(AppConfig(appKey: 'x').totalIsolate, Platform.numberOfProcessors);
    });
  });
}

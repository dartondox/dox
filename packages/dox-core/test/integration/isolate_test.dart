import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'requirements/config/api_router.dart';
import 'requirements/handler.dart';

AppConfig isolateConfig = AppConfig(
  /// application key
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',

  /// application server port
  serverPort: 50010,

  /// total multi-thread isolate to run
  totalIsolate: 1,

  /// response handler
  responseHandler: ResponseHandler(),

  /// routers
  routers: <Router>[
    ApiRouter(),
  ],
);

String baseUrl = 'http://localhost:${isolateConfig.serverPort}';

class ExampleService implements DoxService {
  @override
  void setup() {}
}

void main() {
  group('Isolate', () {
    setUpAll(() async {
      Dox().initialize(isolateConfig);
      Dox().addService(ExampleService());
      Dox().totalIsolate(5);
      await Dox().startServer();
    });

    tearDownAll(() async {
      DoxIsolate().killAll();
    });

    test('test', () async {
      Uri url = Uri.parse('$baseUrl/api/ping');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(DoxIsolate().isolates.length, 5 - 1);
    });
  });
}

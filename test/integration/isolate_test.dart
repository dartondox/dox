import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/dox_isolate.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'requirements/config/api_router.dart';
import 'requirements/handler.dart';

class Config extends AppConfig {
  @override
  int get totalIsolate => 2;

  @override
  String get appKey => '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';

  int _serverPort = 50010;

  @override
  int get serverPort => _serverPort;

  set serverPort(int val) => _serverPort = val;

  @override
  CORSConfig get cors => CORSConfig(
        allowOrigin: '*',
      );

  @override
  ResponseHandlerInterface get responseHandler => ResponseHandler();

  @override
  List<Router> get routers => <Router>[ApiRouter()];
}

Config config = Config();
String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
  group('Isolate', () {
    setUpAll(() async {
      Dox().initialize(config);
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
      expect(DoxIsolate().isolates.length, 2);
    });
  });
}

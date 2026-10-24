import 'package:dox_app/config/app.dart';
import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

String get baseUrl => 'http://localhost:${Dox().server.httpServer.port}';

void main() {
  setUpAll(() async {
    // port 0: the OS picks a free port, so test files can run in parallel.
    // Set it before the app reads its env.
    Env().load();
    Env().env['APP_PORT'] = '0';
    // .env.example has no APP_KEY, so give the test one.
    if ((Env().env['APP_KEY'] ?? '').isEmpty) {
      Env().env['APP_KEY'] = 'test-key-for-the-app-tests-only1';
    }
    Dox().initialize(appConfig);
    // one isolate: with port 0 each isolate gets its own port
    Dox().totalIsolate(1);
    await Dox().startServer();
    await Future<dynamic>.delayed(Duration(milliseconds: 500));
  });

  test('ping route', () async {
    Uri url = Uri.parse('$baseUrl/api/ping');
    http.Response response = await http.get(url);
    expect(response.statusCode, 200);
    expect(response.body, 'pong');
  });
}

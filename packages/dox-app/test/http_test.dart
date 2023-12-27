import 'package:dox_app/config/app.dart';
import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

String baseUrl = 'http://localhost:${appConfig.serverPort}';

void main() {
  setUpAll(() async {
    Dox().initialize(appConfig);
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

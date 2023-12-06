import 'package:dox_app/config/app.dart';
import 'package:dox_app/services/auth_service.dart';
import 'package:dox_app/services/websocket_service.dart';
import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

String baseUrl = 'http://localhost:${appConfig.serverPort}';

void main() {
  setUpAll(() async {
    Dox().initialize(appConfig);
    Dox().addService(AuthService());
    Dox().addService(WebsocketService());
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

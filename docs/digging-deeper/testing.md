# Testing

## Integration test

```dart
import 'package:http/http.dart' as http;

Config config = Config();
String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
    setUpAll(() async {
        Dox().initialize(config);
        await Dox().startServer();

        // for for few seconds to fully started http server
        await Future<dynamic>.delayed(Duration(milliseconds: 500));
    });

    test('/api/ping route', () async {
        var url = Uri.parse('$baseUrl/api/ping');
        var response = await http.get(url);
        expect(response.statusCode, 200);
        expect(response.body, 'pong');
    });
}
```
import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import 'requirements/config/app.dart';

String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
  group('Http |', () {
    setUpAll(() async {
      await startHttpServer(config);
    });

    tearDownAll(() async {
      await Dox().server.close();
    });

    test('date response', () async {
      Route.get('/date/response', (DoxRequest req, String name) {
        return DateTime(2023);
      });

      /// response DateTime
      Uri url = Uri.parse('$baseUrl/date/response');
      http.Response res = await http.get(url);
      expect(res.statusCode, 200);
      expect(res.body, '2023-01-01T00:00:00.000');
    });

    test('date response', () async {
      Route.get('/date/response/json', (DoxRequest req, String name) {
        return <String, dynamic>{
          'date': DateTime(2023),
        };
      });

      /// response DateTime in json
      Uri url2 = Uri.parse('$baseUrl/date/response/json');
      http.Response res2 = await http.get(url2);
      Map<String, dynamic> data = jsonDecode(res2.body);
      expect(res2.statusCode, 200);
      expect(data['date'], '2023-01-01T00:00:00.000');
    });
  });
}

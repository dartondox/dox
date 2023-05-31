import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'requirements/config/app.dart';

Config config = Config();
String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
  group('Http |', () {
    setUpAll(() async {
      config.serverPort = 50012;
      Dox().initialize(config);
      await Future.delayed(Duration(milliseconds: 500));
    });

    tearDownAll(() {
      Dox().server.close();
    });

    test('validation failed', () async {
      Route.post('/validation', (DoxRequest req) {
        req.validate({
          'name': 'required',
          'email': 'required|email',
        });
        return 'pong';
      });

      var url = Uri.parse('$baseUrl/validation');
      var res = await http.post(url);

      expect(res.statusCode, 422);
      expect(res.body.contains('email is required'), true);
      expect(res.body.contains('name is required'), true);
    });

    test('validation passed', () async {
      Route.post('/validation_passed', (DoxRequest req) {
        req.validate({
          'name': 'required',
          'email': 'required|email',
        });
        return 'pong';
      });

      var url = Uri.parse('$baseUrl/validation_passed');
      var res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "name": 'dox',
          "email": 'support@dartondox.dev',
        }),
      );

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
    });
  });
}

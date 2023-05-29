import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'core/config/app.dart';
import 'core/controllers/example.controller.dart';

Config config = Config();
String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
  group('Http |', () {
    setUpAll(() async {
      config.serverPort = 50011;
      Dox().initialize(config);
      await Future.delayed(Duration(milliseconds: 500));
    });

    tearDownAll(() {
      Dox().server.close();
    });

    test('ping -> pong', () async {
      Route.get('/ping', (DoxRequest req) {
        return 'pong';
      });

      var url = Uri.parse('$baseUrl/ping');
      var response = await http.get(url);

      expect(response.statusCode, 200);
      expect(response.body, 'pong');
    });

    test('param route', () async {
      Route.get('/ping/{name}', (DoxRequest req, String name) {
        return 'pong $name';
      });

      var url = Uri.parse('$baseUrl/ping/dox');
      var response = await http.get(url);

      expect(response.statusCode, 200);
      expect(response.body, 'pong dox');
    });

    test('double param route', () async {
      Route.get('/ping/{name}/{type}',
          (DoxRequest req, String name, String type) {
        return 'pong $name $type';
      });

      var url = Uri.parse('$baseUrl/ping/dox/framework');
      var response = await http.get(url);

      expect(response.statusCode, 200);
      expect(response.body, 'pong dox framework');
    });

    test('json response', () async {
      var responseData = {"ping": "pong"};
      Route.get('/json', (DoxRequest req) {
        return responseData;
      });

      var url = Uri.parse('$baseUrl/json');
      var response = await http.get(url);

      expect(response.statusCode, 200);
      expect(response.body, jsonEncode(responseData));
      expect(
          response.headers['content-type']?.contains('application/json'), true);
    });

    test('http exception', () async {
      Route.get('/http_exception', ExampleController().httpException);

      var url = Uri.parse('$baseUrl/http_exception');
      var response = await http.get(url);

      expect(response.statusCode, 401);
      expect(response.body, 'Failed to authorize');
    });

    test('list', () async {
      var responseData = ['1', '2', '4'];
      Route.get('/list', (DoxRequest req) {
        return responseData;
      });

      var url = Uri.parse('$baseUrl/list');
      var response = await http.get(url);

      expect(response.statusCode, 200);
      expect(response.body, jsonEncode(responseData));
    });

    test('custom status', () async {
      Route.get('/custom_status', (DoxRequest req) {
        return response('pong').statusCode(207);
      });

      var url = Uri.parse('$baseUrl/custom_status');
      var res = await http.get(url);

      expect(res.statusCode, 207);
      expect(res.body, 'pong');
    });

    test('custom header', () async {
      Route.get('/custom_header', (DoxRequest req) {
        return response('pong').header('x-key', 'ABCD');
      });

      var url = Uri.parse('$baseUrl/custom_header');
      var res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(res.headers['x-key'], 'ABCD');
    });
  });
}

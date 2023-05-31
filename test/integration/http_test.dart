import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'requirements/config/app.dart';
import 'requirements/controllers/example.controller.dart';
import 'requirements/requests/blog_request.dart';

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

    test('cache response', () async {
      Route.get('/cache_response', (DoxRequest req) {
        return response('pong').cache(Duration(seconds: 10));
      });

      var url = Uri.parse('$baseUrl/cache_response');
      var res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(res.headers['cache-control'], 'max-age=10');
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

    test('content type', () async {
      Route.get('/content_type', (DoxRequest req) {
        return response('pong').contentType(ContentType.text);
      });

      var url = Uri.parse('$baseUrl/content_type');
      var res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(res.headers['content-type'], 'text/plain; charset=utf-8');
    });

    test('dox request', () async {
      Route.post('/with_headers/{id}', (DoxRequest req) {
        expect(req.header('x-auth-key'), 'Bearer 1234');
        expect(req.headers['x-auth-key'], 'Bearer 1234');
        expect(req.input('title'), 'hello');
        expect(req.body['title'], 'hello');
        expect(req.param['id'], '1');
        expect(req.method, 'POST');
        expect(req.uri.path, '/with_headers/1');
        expect(req.all()['title'], 'hello');
        expect(req.has('title'), true);
        expect(req.has('not_exist'), false);
        expect(req.only(['title'])['title'], 'hello');
        expect(req.isJson(), true);
        expect(req.host().contains('localhost'), true);
        expect(req.ip(), '127.0.0.1');
        expect(req.isFormData(), false);

        return response('pong').withHeaders({
          'x-key': 'ABCD',
        });
      });

      var url = Uri.parse('$baseUrl/with_headers/1');
      var res = await http.post(
        url,
        headers: {
          'content-type': 'application/json',
          'x-auth-key': 'Bearer 1234',
        },
        body: jsonEncode({
          'title': 'hello',
        }),
      );

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(res.headers['x-key'], 'ABCD');
    });

    test('cookie response', () async {
      Route.get('/custom_header', (DoxRequest req) {
        var cookie = DoxCookie('x-key', 'ABCD');
        var cookie2 = DoxCookie('x-key2', 'ABCD', encrypt: false);
        return response('pong').cookie(cookie).cookie(cookie2);
      });

      var url = Uri.parse('$baseUrl/custom_header');
      var res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(res.headers['set-cookie'],
          'x-key=Ewh5wQRRo0v5ljLQpLNAcA==; Max-Age=3600000,x-key2=ABCD; Max-Age=3600000');
    });

    test('custom form request', () async {
      Route.post('/custom_form_request', (BlogRequest req) {
        expect(req.title, 'hello');
        return req.title;
      });

      var url = Uri.parse('$baseUrl/custom_form_request');
      var res =
          await http.post(url, body: jsonEncode({'title': 'hello'}), headers: {
        'content-type': 'application/json',
      });

      expect(res.statusCode, 200);
      expect(res.body, 'hello');
    });
  });
}

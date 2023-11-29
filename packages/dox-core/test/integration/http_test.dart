import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import 'requirements/config/app.dart';
import 'requirements/controllers/example.controller.dart';
import 'requirements/middleware/custom_middleware.dart';
import 'requirements/requests/blog_request.dart';

Config config = Config();
String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
  group('Http |', () {
    setUpAll(() async {
      await startHttpServer(config);
    });

    tearDownAll(() async {
      await Dox().server.close();
    });

    test('ping -> pong', () async {
      DoxRequest middlewareFn(DoxRequest req) {
        return req;
      }

      String pong(DoxRequest req) {
        return 'pong';
      }

      Route.get('/ping', <dynamic>[middlewareFn, ClassBasedMiddleware(), pong]);

      Uri url = Uri.parse('$baseUrl/ping');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
    });

    test('ping -> pong', () async {
      DoxRequest middlewareFn(DoxRequest req) {
        return req;
      }

      String pong(DoxRequest req) {
        return 'pong';
      }

      Route.middleware(<dynamic>[middlewareFn, ClassBasedMiddleware()], () {
        Route.get('/middleware_route', pong);
      });

      Uri url = Uri.parse('$baseUrl/middleware_route');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
    });

    test('param route', () async {
      Route.get('/ping/{name}', (DoxRequest req, String name) {
        return 'pong $name';
      });

      Uri url = Uri.parse('$baseUrl/ping/dox');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong dox');
    });

    test('throw an error', () async {
      Route.get('/exception', (DoxRequest req, String name) {
        throw Exception('something wrong');
      });

      Uri url = Uri.parse('$baseUrl/exception');
      http.Response response = await http.get(url);

      expect(response.statusCode, 500);
    });

    test('route not found', () async {
      Uri url = Uri.parse('$baseUrl/non/exist/route');
      http.Response response = await http.get(url);
      expect(response.body, 'GET /non/exist/route not found');
      expect(response.statusCode, 404);
    });

    test('OPTIONS route', () async {
      Uri url = Uri.parse('$baseUrl/non/exist/route');
      http.StreamedResponse response =
          await http.Client().send(http.Request('OPTIONS', url));
      expect(response.statusCode, 200);
    });

    test('double param route', () async {
      Route.get('/ping/{name}/{type}',
          (DoxRequest req, String name, String type) {
        return 'pong $name $type';
      });

      Uri url = Uri.parse('$baseUrl/ping/dox/framework');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong dox framework');
    });

    test('json response', () async {
      Map<String, String> responseData = <String, String>{'ping': 'pong'};
      Route.get('/json', (DoxRequest req) {
        return responseData;
      });

      Uri url = Uri.parse('$baseUrl/json');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, jsonEncode(responseData));
      expect(res.headers['content-type']?.contains('application/json'), true);
    });

    test('http exception', () async {
      Route.get('/http_exception', ExampleController().httpException);

      Uri url = Uri.parse('$baseUrl/http_exception');
      http.Response res = await http.get(url);

      expect(res.statusCode, 422);
    });

    test('list', () async {
      List<String> responseData = <String>['1', '2', '4'];
      Route.get('/list', (DoxRequest req) {
        return responseData;
      });

      Uri url = Uri.parse('$baseUrl/list');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, jsonEncode(responseData));
    });

    test('cache response', () async {
      Route.get('/cache_response', (DoxRequest req) {
        return response('pong').cache(Duration(seconds: 10));
      });

      Uri url = Uri.parse('$baseUrl/cache_response');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(res.headers['cache-control'], 'max-age=10');
    });

    test('domain test', () async {
      Route.domain('localhost:${config.serverPort}', () {
        Route.get('/domain/test', (DoxRequest doxRequest) {
          return 'pong';
        });
      });

      Uri url = Uri.parse('$baseUrl/domain/test');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
    });

    test('custom status', () async {
      Route.get('/custom_status', (DoxRequest req) {
        return response('pong').statusCode(207);
      });

      Uri url = Uri.parse('$baseUrl/custom_status');
      http.Response res = await http.get(url);

      expect(res.statusCode, 207);
      expect(res.body, 'pong');
    });

    test('custom header', () async {
      Route.get('/custom_header', (DoxRequest req) {
        return response('pong').header('x-key', 'ABCD');
      });

      Uri url = Uri.parse('$baseUrl/custom_header');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(res.headers['x-key'], 'ABCD');
    });

    test('content type', () async {
      Route.get('/content_type', (DoxRequest req) {
        return response('pong').contentType(ContentType.text);
      });

      Uri url = Uri.parse('$baseUrl/content_type');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(res.headers['content-type'], 'text/plain; charset=utf-8');
    });

    test('cookie response', () async {
      Route.get('/cookie_response', (DoxRequest req) {
        DoxCookie cookie = DoxCookie('x-key', 'ABCD');
        DoxCookie cookie2 = DoxCookie('x-key2', 'ABCD', encrypt: false);
        return response('pong').cookie(cookie).cookie(cookie2);
      });

      Uri url = Uri.parse('$baseUrl/cookie_response');
      http.Response res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(res.headers['set-cookie'],
          'x-key=Ewh5wQRRo0v5ljLQpLNAcA==; Max-Age=3600000,x-key2=ABCD; Max-Age=3600000');
    });

    test('custom form request', () async {
      Route.post('/custom_form_request', (BlogRequest req) {
        return <String, dynamic>{
          'title': req.title,
          'bar': req.input('bar'),
        };
      });

      Uri url = Uri.parse('$baseUrl/custom_form_request');
      http.Response res = await http.post(
        url,
        body: jsonEncode(<String, String>{
          'title': 'hello',
          'foo': 'bar',
        }),
        headers: <String, String>{
          'content-type': 'application/json',
        },
      );
      Map<String, dynamic> jsond = jsonDecode(res.body);
      expect(res.statusCode, 200);
      expect(jsond['title'], 'hello');
      expect(jsond['bar'], 'bar');
    });
  });
}

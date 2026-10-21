import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import 'requirements/config/app.dart';
import 'requirements/controllers/example.controller.dart';
import 'requirements/middleware/custom_middleware.dart';
import '../dtos/rules.dto.dart';

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

    test('first matching route wins, also for plain paths', () async {
      Route.get('/order_check/{id}', (DoxRequest req) => 'param');
      Route.get('/order_check/plain', (DoxRequest req) => 'plain');
      Route.get('/order_plain', (DoxRequest req) => 'first');
      Route.get('/order_plain', (DoxRequest req) => 'second');

      http.Response res = await http.get(
        Uri.parse('$baseUrl/order_check/plain'),
      );
      expect(res.body, 'param');
      res = await http.get(Uri.parse('$baseUrl/order_plain/'));
      expect(res.body, 'first');
    });

    test('async middleware, then sync controller', () async {
      Future<DoxRequest> slow(DoxRequest req) async {
        await Future<void>.delayed(Duration.zero);
        return req;
      }

      Route.get('/async_mw', <dynamic>[
        slow,
        ClassBasedMiddleware(),
        (DoxRequest req) => 'done',
      ]);

      http.Response res = await http.get(Uri.parse('$baseUrl/async_mw'));
      expect(res.statusCode, 200);
      expect(res.body, 'done');
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
      http.StreamedResponse response = await http.Client().send(
        http.Request('OPTIONS', url),
      );
      expect(response.statusCode, 204);
    });

    test('double param route', () async {
      Route.get('/ping/{name}/{type}', (
        DoxRequest req,
        String name,
        String type,
      ) {
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
      expect(
        res.headers['set-cookie'],
        'x-key=Ewh5wQRRo0v5ljLQpLNAcA==; Max-Age=3600,x-key2=ABCD; Max-Age=3600',
      );
    });

    test('cors preflight without options route', () async {
      Route.enabledCors(() {
        Route.post('/cors_preflight', (DoxRequest req) => 'ok');
      });

      http.Request req = http.Request(
        'OPTIONS',
        Uri.parse('$baseUrl/cors_preflight'),
      );
      req.headers['origin'] = 'http://example.com';
      req.headers['access-control-request-method'] = 'POST';
      http.StreamedResponse res = await req.send();

      expect(res.statusCode, 204);
      expect(res.headers['access-control-allow-origin'], '*');
      expect(
        res.headers['access-control-allow-methods'],
        'GET,POST,DELETE,PUT,PATCH',
      );

      /// no route for the path, cors is disabled in config
      http.StreamedResponse res2 = await http.Request(
        'OPTIONS',
        Uri.parse('$baseUrl/no_such_route'),
      ).send();
      expect(res2.statusCode, 204);
      expect(res2.headers['access-control-allow-origin'], null);
    });

    test('a DTO as a controller parameter', () async {
      Route.post('/dto_param', (CreateUser body) {
        return <String, dynamic>{'name': body.name, 'role': body.role.name};
      });

      Uri url = Uri.parse('$baseUrl/dto_param');
      http.Response res = await http.post(
        url,
        body: jsonEncode(<String, String>{
          'name': ' hello ',
          'email': 'a@dox.dev',
          'foo': 'bar',
        }),
        headers: <String, String>{'content-type': 'application/json'},
      );
      Map<String, dynamic> jsond = jsonDecode(res.body);
      expect(res.statusCode, 200);
      expect(jsond, <String, dynamic>{'name': 'hello', 'role': 'user'});
    });
  });
}

import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/aes_encryptor.dart';
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
    test('dox request', () async {
      Route.post('/with_headers/{id}', (DoxRequest req) async {
        return response(<String, dynamic>{
          'x-auth-key': req.header('x-auth-key'),
          'x-auth-key2': req.headers['x-auth-key'],
          'title': req.input('title'),
          'title2': req.body['title'],
          'title3': req.all()['title'],
          'title4': req.only(<String>['title'])['title'],
          'id': req.param['id'],
          'method': req.method,
          'path': req.uri.path,
          'has_title': req.has('title'),
          'has_desc': req.has('desc'),
          'is_json': req.isJson(),
          'is_form_data': req.isFormData(),
          'host': req.host(),
          'ip': req.ip(),
        }).withHeaders(<String, String>{
          'x-key': 'ABCD',
        });
      });

      Uri url = Uri.parse('$baseUrl/with_headers/1');
      http.Response res = await http.post(
        url,
        headers: <String, String>{
          'content-type': 'application/json',
          'x-auth-key': 'Bearer 1234',
        },
        body: jsonEncode(<String, String>{
          'title': 'hello',
        }),
      );
      Map<String, dynamic> jsond = jsonDecode(res.body);
      expect(jsond['x-auth-key'], 'Bearer 1234');
      expect(jsond['x-auth-key2'], 'Bearer 1234');
      expect(jsond['title'], 'hello');
      expect(jsond['title2'], 'hello');
      expect(jsond['title3'], 'hello');
      expect(jsond['title4'], 'hello');
      expect(jsond['id'], '1');
      expect(jsond['method'], 'POST');
      expect(jsond['path'], '/with_headers/1');
      expect(jsond['has_title'], true);
      expect(jsond['has_desc'], false);
      expect(jsond['is_json'], true);
      expect(jsond['is_form_data'], false);
      expect(jsond['host'].toString().contains('localhost'), true);
      expect(jsond['ip'].toString().contains('127.0.0.1'), true);
      expect(res.statusCode, 200);
      expect(res.headers['x-key'], 'ABCD');
    });

    test('get cookies', () async {
      String authKeyValue = 'auth-key-value';

      Route.post('/get_cookies', (DoxRequest req) async {
        return <String, dynamic>{
          'cookie': req.cookie('auth-key'),
          'userAgent': req.userAgent(),
          'origin': req.origin(),
          'referer': req.referer(),
        };
      });

      String cookieValue = AESEncryptor.encode(authKeyValue, config.appKey);

      http.Response res = await http.post(
        Uri.parse('$baseUrl/get_cookies'),
        headers: <String, String>{
          'cookie': 'auth-key=$cookieValue',
          'user-agent': 'dox-test',
          'origin': 'localhost',
          'referer': 'referer',
        },
      );
      Map<String, dynamic> jsond = jsonDecode(res.body);
      expect(jsond['cookie'], cookieValue);
      expect(jsond['userAgent'], 'dox-test');
      expect(jsond['origin'], 'localhost');
      expect(jsond['referer'], 'referer');
    });

    test('add & merge request input', () async {
      Route.post('/request/add/merge', (DoxRequest req) async {
        req.add('bar', 'foo');
        req.merge(<String, String>{'name': 'dox'});
        return <String, dynamic>{
          'bar': req.input('bar'),
          'title': req.input('title'),
          'name': req.input('name'),
        };
      });

      Uri url = Uri.parse('$baseUrl/request/add/merge');
      http.Response res = await http.post(
        url,
        headers: <String, String>{
          'content-type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'title': 'hello',
        }),
      );
      Map<String, dynamic> jsond = jsonDecode(res.body);
      expect(jsond['title'], 'hello');
      expect(jsond['bar'], 'foo');
      expect(jsond['name'], 'dox');
    });

    test('return request support json encode', () async {
      Route.post('/request/add/merge', (DoxRequest req) async {
        return req;
      });

      Uri url = Uri.parse('$baseUrl/request/add/merge');
      http.Response res = await http.post(
        url,
        headers: <String, String>{
          'content-type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'title': 'hello',
        }),
      );
      Map<String, dynamic> jsond = jsonDecode(res.body);
      expect(jsond['title'], 'hello');
    });
  });
}

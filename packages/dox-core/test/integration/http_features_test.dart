import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/start_http_server.dart';

const String appKey = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';
const String oldKey = 'zP0q8xN2mVb7Lc4Rt6Yw1Ks3Hd9Fg5Ja';

String get baseUrl => 'http://localhost:${Dox().server.httpServer.port}';

Uri url(String path) => Uri.parse('$baseUrl$path');

void main() {
  setUpAll(() async {
    Route.get('/feat/items', (DoxRequest req) => 'list');
    Route.post('/feat/items', (DoxRequest req) => 'made');
    Route.delete('/feat/items/{id}', (DoxRequest req, String id) => id);
    Route.get('/feat/abort', (DoxRequest req) => abort(403));
    Route.get('/feat/abort-text', (DoxRequest req) {
      abort(409, 'The email is taken');
    });
    Route.get('/feat/unavailable', (DoxRequest req) {
      throw HttpStatusException(
        503,
        headers: <String, String>{'retry-after': '60'},
      );
    });
    Route.get('/feat/forbidden', (DoxRequest req) {
      throw ForbiddenHttpException(message: 'Not your post');
    });
    Route.post('/feat/input', (DoxRequest req) {
      return <String, dynamic>{
        'tags': req.input('tags'),
        'city': req.input('address')?['city'],
        'name': req.input('name'),
      };
    });
    Route.get('/feat/query', (DoxRequest req) {
      return <String, dynamic>{'tags': req.query['tags'], 'q': req.query['q']};
    });
    Route.get('/feat/cookie', (DoxRequest req) {
      return <String, String?>{'token': req.cookie('token')};
    });
    await startHttpServer(
      AppConfig(
        appKey: appKey,
        previousKeys: <String>[oldKey],
        serverPort: 0,
        totalIsolate: 1,
      ),
    );
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  group('405 |', () {
    test('a path with routes for other methods gives 405 and Allow', () async {
      http.Response res = await http.put(url('/feat/items'));
      expect(res.statusCode, 405);
      expect(res.headers['allow'], 'GET, POST, HEAD');
      expect(jsonDecode(res.body)['code'], 'method_not_allowed');
    });

    test('a param route counts too', () async {
      http.Response res = await http.get(url('/feat/items/5'));
      expect(res.statusCode, 405);
      expect(res.headers['allow'], 'DELETE');
    });

    test('a path with no route is still 404', () async {
      http.Response res = await http.put(url('/feat/nothing'));
      expect(res.statusCode, 404);
      expect(res.headers['allow'], isNull);
    });
  });

  group('abort and HttpStatusException |', () {
    test('abort(403) gives the default code and message', () async {
      http.Response res = await http.get(url('/feat/abort'));
      expect(res.statusCode, 403);
      expect(res.body, '{"code":"forbidden","message":"Forbidden"}');
    });

    test('abort with a message', () async {
      http.Response res = await http.get(url('/feat/abort-text'));
      expect(res.statusCode, 409);
      expect(res.body, '{"code":"conflict","message":"The email is taken"}');
    });

    test('headers are sent', () async {
      http.Response res = await http.get(url('/feat/unavailable'));
      expect(res.statusCode, 503);
      expect(res.headers['retry-after'], '60');
    });

    test('ForbiddenHttpException', () async {
      http.Response res = await http.get(url('/feat/forbidden'));
      expect(res.statusCode, 403);
      expect(res.body, '{"code":"forbidden","message":"Not your post"}');
    });
  });

  group('form arrays |', () {
    test('urlencoded body nests bracket keys', () async {
      http.Response res = await http.post(
        url('/feat/input'),
        headers: <String, String>{
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: 'tags%5B%5D=a&tags%5B%5D=b&address[city]=Yangon&name=x&name=y',
      );
      expect(jsonDecode(res.body), <String, dynamic>{
        'tags': <String>['a', 'b'],
        'city': 'Yangon',
        // a repeated plain key keeps its last value
        'name': 'y',
      });
    });

    test('multipart body nests bracket keys', () async {
      http.MultipartRequest req = http.MultipartRequest(
        'POST',
        url('/feat/input'),
      )..fields['address[city]'] = 'Mandalay';
      req.files.add(http.MultipartFile.fromString('tags[]', 'one'));
      req.files.add(http.MultipartFile.fromString('tags[]', 'two'));
      http.Response res = await http.Response.fromStream(await req.send());
      Map<String, dynamic> body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['city'], 'Mandalay');
      expect((body['tags'] as List<dynamic>).length, 2);
    });

    test('query string nests bracket keys', () async {
      http.Response res = await http.get(
        url('/feat/query?tags[]=a&tags[]=b&q=1&q=2'),
      );
      expect(res.body, '{"tags":["a","b"],"q":"2"}');
    });
  });

  group('previousKeys |', () {
    String cookieFor(String key) {
      String value = AESEncryptor.encode(
        'secret',
        key,
        associatedData: 'token',
        purpose: KeyDerivation.cookie,
      );
      return 'token=$value';
    }

    test('a cookie made with an old key is still read', () async {
      for (String key in <String>[appKey, oldKey]) {
        http.Response res = await http.get(
          url('/feat/cookie'),
          headers: <String, String>{'cookie': cookieFor(key)},
        );
        expect(res.body, '{"token":"secret"}');
      }
    });

    test('a cookie made with an unknown key gives null', () async {
      http.Response res = await http.get(
        url('/feat/cookie'),
        headers: <String, String>{
          'cookie': cookieFor('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
        },
      );
      expect(res.body, '{"token":null}');
    });
  });
}

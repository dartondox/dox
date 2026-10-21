import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../dtos/files.dto.dart';
import '../dtos/nested.dto.dart';
import '../dtos/rules.dto.dart';
import '../utils/start_http_server.dart';
import 'requirements/config/app.dart';

String baseUrl = 'http://localhost:${config.serverPort}';

const List<int> png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0];

Future<http.Response> postJson(String path, Object? body) {
  return http.post(
    Uri.parse('$baseUrl$path'),
    headers: <String, String>{'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
}

Future<http.Response> get(String path, {Map<String, String>? headers}) {
  return http.get(Uri.parse('$baseUrl$path'), headers: headers);
}

Map<String, dynamic> json(http.Response res) {
  return jsonDecode(res.body) as Map<String, dynamic>;
}

void main() {
  group('DTO over http |', () {
    setUpAll(() async {
      await startHttpServer(config);

      Route.post('/users', (CreateUser body) {
        return <String, dynamic>{'name': body.name, 'age': body.age};
      });
      Route.post('/orders', (CreateOrder body) {
        return <String, dynamic>{'items': body.items.length};
      });
      Route.get('/orders', (CreateOrder query) {
        return <String, dynamic>{
          'city': query.address.city,
          'quantity': query.items.first.quantity,
        };
      });
      Route.get('/search', (DoxRequest req, SearchUsers query) {
        return <String, dynamic>{
          'q': query.q,
          'page': query.page,
          'tags': query.tags,
        };
      });
      Route.post('/search', (SearchUsers query) {
        return <String, dynamic>{'page': query.page};
      });
      Route.post('/validate', (DoxRequest req) async {
        CreateUser user = await req.validate<CreateUser>();
        return <String, dynamic>{'name': user.name};
      });
      Route.post('/validate-query', (DoxRequest req) async {
        AllTypes value = await req.validate<AllTypes>(source: Source.query);
        return <String, dynamic>{'i': value.i};
      });
      Route.patch('/users/{id}', (int id, UpdateUser body, DoxRequest req) {
        return <String, dynamic>{
          'id': id,
          'bio_sent': body.bio.isPresent,
          'bio': body.bio.isPresent ? body.bio.value : 'missing',
          'method': req.method,
        };
      });
      Route.get('/types/{a}/{b}/{c}/{d}/{e}', (
        String a,
        int b,
        double c,
        num d,
        bool e,
      ) {
        return <String, dynamic>{'a': a, 'b': b, 'c': c, 'd': d, 'e': e};
      });
      Route.get('/optional/{id?}', (int? id) {
        return <String, dynamic>{'id': id};
      });
      Route.post('/upload', (UploadAvatar input) {
        return <String, dynamic>{
          'avatar': input.avatar.filename,
          'documents': input.documents.length,
          'title': input.title,
        };
      });
      Route.get('/locale', (DoxRequest req) {
        return <String, dynamic>{'locale': req.locale};
      });
    });

    tearDownAll(() async {
      await Dox().server.close();
    });

    test('a DTO parameter gets the checked body', () async {
      http.Response res = await postJson('/users', <String, dynamic>{
        'name': ' Ann ',
        'email': 'ann@dox.dev',
        'age': 20,
      });
      expect(res.statusCode, 200);
      expect(json(res), <String, dynamic>{'name': 'Ann', 'age': 20});
    });

    test('bad input answers 422 with a flat map', () async {
      http.Response res = await postJson('/orders', <String, dynamic>{
        'address': <String, dynamic>{'post_code': '10110'},
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Shoes', 'quantity': 2},
          <String, dynamic>{'name': 'Socks', 'quantity': 0},
        ],
      });
      expect(res.statusCode, 422);
      expect(json(res), <String, dynamic>{
        'address.city': 'The city is required',
        'items.1.quantity': 'The quantity must be greater than 0',
      });
    });

    test('JSON is strict', () async {
      http.Response res = await postJson('/users', <String, dynamic>{
        'name': 'Ann',
        'email': 'ann@dox.dev',
        'age': '20',
      });
      expect(res.statusCode, 422);
      expect(json(res), <String, dynamic>{'age': 'The age must be an integer'});
    });

    test('GET reads the query, with text converted', () async {
      http.Response res = await get('/search?q=dox&page=2&tags=a&tags=b');
      expect(res.statusCode, 200);
      expect(json(res), <String, dynamic>{
        'q': 'dox',
        'page': 2,
        'tags': <String>['a', 'b'],
      });
      http.Response bad = await get('/search?page=x');
      expect(bad.statusCode, 422);
      expect(json(bad), <String, dynamic>{
        'page': 'The page must be an integer',
      });
    });

    test('bracket keys make nested objects and lists', () async {
      http.Response res = await get(
        '/orders?address[city]=Bangkok&address[post_code]=10110'
        '&items[3][name]=a&items[3][quantity]=2',
      );
      expect(res.statusCode, 200);
      expect(json(res), <String, dynamic>{'city': 'Bangkok', 'quantity': 2});
    });

    test('too many list items answers 422', () async {
      http.Response res = await get('/search?tags[1000]=a');
      expect(res.statusCode, 422);
      expect(json(res).keys, <String>['_root']);
    });

    test('@Dto(source: Source.query) reads the query on POST', () async {
      http.Response res = await http.post(
        Uri.parse('$baseUrl/search?page=3'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'page': 9}),
      );
      expect(json(res), <String, dynamic>{'page': 3});
    });

    test('req.validate<T>() and a source for one call', () async {
      http.Response res = await postJson('/validate', <String, dynamic>{
        'name': 'Bob',
        'email': 'bob@dox.dev',
      });
      expect(json(res), <String, dynamic>{'name': 'Bob'});
      http.Response bad = await postJson('/validate', <String, dynamic>{});
      expect(bad.statusCode, 422);
      http.Response query = await http.post(
        Uri.parse('$baseUrl/validate-query?i=5'),
      );
      expect(json(query), <String, dynamic>{'i': 5});
    });

    test('form data is text, converted', () async {
      http.Response res = await http.post(
        Uri.parse('$baseUrl/users'),
        body: <String, String>{
          'name': 'Ann',
          'email': 'ann@dox.dev',
          'age': '30',
        },
      );
      expect(res.statusCode, 200);
      expect(json(res), <String, dynamic>{'name': 'Ann', 'age': 30});
    });

    test('a body that is not valid JSON answers 400', () async {
      http.Response res = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: '{bad',
      );
      expect(res.statusCode, 400);
    });

    test('another content type answers 415', () async {
      http.Response res = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: <String, String>{'Content-Type': 'text/plain'},
        body: 'hello',
      );
      expect(res.statusCode, 415);
    });

    test('a JSON body that is not an object answers 422 _root', () async {
      http.Response res = await postJson('/users', <int>[1, 2]);
      expect(res.statusCode, 422);
      expect(json(res), <String, dynamic>{
        '_root': 'The _root must be an object',
      });
    });

    test('Maybe, a typed path param and DoxRequest anywhere', () async {
      http.Response missing = await http.patch(
        Uri.parse('$baseUrl/users/7'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{}),
      );
      expect(json(missing), <String, dynamic>{
        'id': 7,
        'bio_sent': false,
        'bio': 'missing',
        'method': 'PATCH',
      });
      http.Response cleared = await http.patch(
        Uri.parse('$baseUrl/users/7'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'bio': null}),
      );
      expect(json(cleared)['bio_sent'], isTrue);
      expect(json(cleared)['bio'], isNull);
    });

    test('path params of every type', () async {
      http.Response res = await get('/types/x/42/4.5/7/true');
      expect(res.statusCode, 200);
      expect(json(res), <String, dynamic>{
        'a': 'x',
        'b': 42,
        'c': 4.5,
        'd': 7,
        'e': true,
      });
    });

    test('a path param that does not fit its type answers 404', () async {
      expect((await get('/types/x/abc/4.5/7/true')).statusCode, 404);
      expect((await get('/types/x/4.5/4.5/7/true')).statusCode, 404);
      expect((await get('/types/x/1/abc/7/true')).statusCode, 404);
      expect((await get('/types/x/1/1/7/yes')).statusCode, 404);
    });

    test('path params are checked before the DTO', () async {
      http.Response res = await http.patch(
        Uri.parse('$baseUrl/users/abc'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'age': 'x'}),
      );
      expect(res.statusCode, 404);
    });

    test('an optional path param', () async {
      expect(json(await get('/optional')), <String, dynamic>{'id': null});
      expect(json(await get('/optional/5')), <String, dynamic>{'id': 5});
    });

    test('multipart: files and text', () async {
      http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );
      request.fields['title'] = 'me';
      request.files.add(
        http.MultipartFile.fromBytes('avatar', png, filename: 'me.png'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'documents[]',
          utf8.encode('%PDF-1.7'),
          filename: 'a.pdf',
        ),
      );
      http.Response res = await http.Response.fromStream(await request.send());
      expect(res.statusCode, 200);
      expect(json(res), <String, dynamic>{
        'avatar': 'me.png',
        'documents': 1,
        'title': 'me',
      });
    });

    test('multipart: a file with the wrong bytes', () async {
      http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          utf8.encode('<svg onload="x"/>'),
          filename: 'me.png',
        ),
      );
      http.Response res = await http.Response.fromStream(await request.send());
      expect(res.statusCode, 422);
      expect(json(res), <String, dynamic>{
        'avatar': 'The avatar must be an image',
      });
    });

    test('locale is the first Accept-Language', () async {
      http.Response res = await get(
        '/locale',
        headers: <String, String>{'Accept-Language': 'th-TH,th;q=0.9,en;q=0.8'},
      );
      expect(json(res), <String, dynamic>{'locale': 'th'});
    });
  });

  group('controller types are read at start |', () {
    RouteData route(String path, Function fn) {
      return RouteData(method: 'GET', path: path, controllers: <dynamic>[fn]);
    }

    test('an unknown type stops the start', () {
      expect(
        () => route('/x', (DateTime when) => 'x').handler,
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('DateTime is not known'),
          ),
        ),
      );
    });

    test('more path params than the route has', () {
      expect(() => route('/x', (int id) => 'x').handler, throwsStateError);
    });

    test('two DTOs', () {
      expect(
        () => route('/x', (CreateUser a, CreateOrder b) => 'x').handler,
        throwsStateError,
      );
    });

    test('named parameters are not supported', () {
      expect(
        () => route('/x', ({DoxRequest? req}) => 'x').handler,
        throwsStateError,
      );
    });
  });
}

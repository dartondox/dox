import 'dart:convert';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import 'requirements/config/app.dart';

String get baseUrl => 'http://localhost:${Dox().server.httpServer.port}';

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
          'has_count': req.has('count'),
          'is_json': req.isJson(),
          'is_form_data': req.isFormData(),
          'host': req.host(),
          'ip': req.ip(),
        }).withHeaders(<String, String>{'x-key': 'ABCD'});
      });

      Uri url = Uri.parse('$baseUrl/with_headers/1');
      http.Response res = await http.post(
        url,
        headers: <String, String>{
          'content-type': 'application/json',
          'x-auth-key': 'Bearer 1234',
        },
        body: jsonEncode(<String, dynamic>{'title': 'hello', 'count': 5}),
      );
      Map<String, dynamic> jsond = jsonDecode(res.body);
      expect(jsond['has_count'], true);
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
      expect(jsond['ip'], '127.0.0.1');
      expect(res.statusCode, 200);
      expect(res.headers['x-key'], 'ABCD');
    });

    test('requestBody tells invalid JSON from no body', () async {
      Route.post('/body_kind', (DoxRequest req) {
        RequestBody body = req.requestBody;
        return <String, dynamic>{
          'kind': body.kind.name,
          'json': body.kind == BodyKind.json ? body.json : null,
        };
      });

      Uri url = Uri.parse('$baseUrl/body_kind');
      Future<Map<String, dynamic>> kindOf(
        Map<String, String> headers,
        String body,
      ) async {
        http.Response res = await http.post(url, headers: headers, body: body);
        return jsonDecode(res.body) as Map<String, dynamic>;
      }

      Map<String, String> json = <String, String>{
        'content-type': 'application/json',
      };
      expect(await kindOf(json, '[1, 2]'), <String, dynamic>{
        'kind': 'json',
        'json': <dynamic>[1, 2],
      });
      expect((await kindOf(json, '{nope'))['kind'], 'invalidJson');
      // package:http sends a String body as text/plain
      expect((await kindOf(<String, String>{}, 'hi'))['kind'], 'other');
      // a JSON content type with an empty body is no body
      expect((await kindOf(json, ''))['kind'], 'none');
      // no body and no content type
      http.Response res = await http.post(url);
      expect(jsonDecode(res.body)['kind'], 'none');
    });

    test('get cookies', () async {
      String authKeyValue = 'auth-key-value';

      Route.post('/get_cookies', (DoxRequest req) async {
        return <String, dynamic>{
          'cookie': req.cookie('auth-key'),
          'bad': req.cookie('bad'),
          'raw': req.cookie('other', decrypt: false),
          'userAgent': req.userAgent(),
          'origin': req.origin(),
          'referer': req.referer(),
        };
      });

      String cookieValue = AESEncryptor.encode(
        authKeyValue,
        config.appKey,
        associatedData: 'auth-key',
        purpose: KeyDerivation.cookie,
      );

      http.Response res = await http.post(
        Uri.parse('$baseUrl/get_cookies'),
        headers: <String, String>{
          'cookie':
              'other=1; bad=AAAAAAAAAAAAAAAAAAAAAAAA; auth-key=$cookieValue',
          'user-agent': 'dox-test',
          'origin': 'localhost',
          'referer': 'referer',
        },
      );
      Map<String, dynamic> jsond = jsonDecode(res.body);
      expect(jsond['cookie'], authKeyValue);
      expect(jsond['raw'], '1');
      expect(jsond['bad'], null);
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
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, String>{'title': 'hello'}),
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
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, String>{'title': 'hello'}),
      );
      Map<String, dynamic> jsond = jsonDecode(res.body);
      expect(jsond['title'], 'hello');
    });
    test('input helpers: dot keys, exists, filled, boolean, integer', () async {
      Route.post('/request/helpers', (DoxRequest req) async {
        return <String, dynamic>{
          'name': req.input('user.name'),
          'item': req.input('items.1.id'),
          'flat': req.input('a.b'),
          'none': req.input('user.age', 30),
          'null_default': req.input('empty_null', 'x'),
          'has_blank': req.has('blank'),
          'exists_blank': req.exists('blank'),
          'exists_null': req.exists('empty_null'),
          'exists_dot': req.exists('user.name'),
          'exists_nope': req.exists('nope'),
          'missing_nope': req.missing('nope'),
          'missing_blank': req.missing('blank'),
          'filled_blank': req.filled('blank'),
          'filled_space': req.filled('space'),
          'filled_name': req.filled('user.name'),
          'filled_list': req.filled('list'),
          'filled_items': req.filled('items'),
          'bool_on': req.boolean('on'),
          'bool_true': req.boolean('t'),
          'bool_no': req.boolean('no'),
          'bool_none': req.boolean('nope'),
          'bool_default': req.boolean('nope', true),
          'int_text': req.integer('page'),
          'int_num': req.integer('count'),
          'int_bad': req.integer('blank', 7),
          'int_none': req.integer('nope'),
          'int_query': req.integer('q'),
          'except': req.except(<String>['user', 'items']).keys.toList(),
          'file': req.file('user.name')?.filename,
          'has_file': req.hasFile('user'),
        };
      });

      http.Response res = await http.post(
        Uri.parse('$baseUrl/request/helpers?q=3'),
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'user': <String, dynamic>{'name': 'dox'},
          'items': <dynamic>[
            <String, dynamic>{'id': 1},
            <String, dynamic>{'id': 2},
          ],
          'a.b': 'flat',
          'a': <String, dynamic>{'b': 'nested'},
          'blank': '',
          'space': '  ',
          'empty_null': null,
          'list': <dynamic>[],
          'on': 'on',
          't': true,
          'no': 'no',
          'page': '12',
          'count': 4.0,
        }),
      );
      Map<String, dynamic> j = jsonDecode(res.body);
      expect(j['name'], 'dox');
      expect(j['item'], 2);
      expect(j['flat'], 'flat');
      expect(j['none'], 30);
      expect(j['null_default'], 'x');
      expect(j['has_blank'], false);
      expect(j['exists_blank'], true);
      expect(j['exists_null'], true);
      expect(j['exists_dot'], true);
      expect(j['exists_nope'], false);
      expect(j['missing_nope'], true);
      expect(j['missing_blank'], false);
      expect(j['filled_blank'], false);
      expect(j['filled_space'], false);
      expect(j['filled_name'], true);
      expect(j['filled_list'], false);
      expect(j['filled_items'], true);
      expect(j['bool_on'], true);
      expect(j['bool_true'], true);
      expect(j['bool_no'], false);
      expect(j['bool_none'], false);
      expect(j['bool_default'], true);
      expect(j['int_text'], 12);
      expect(j['int_num'], 4);
      expect(j['int_bad'], 7);
      expect(j['int_none'], 0);
      expect(j['int_query'], 3);
      expect(j['except'], isNot(contains('user')));
      expect(j['except'], isNot(contains('items')));
      expect(j['except'], contains('blank'));
      expect(j['file'], null);
      expect(j['has_file'], false);
    });

    test('url helpers: path, fullUrl, pathIs, routeIs, bearerToken', () async {
      Route.get('/admin/users/{id}', (DoxRequest req) async {
        return <String, dynamic>{
          'path': req.path(),
          'full': req.fullUrl(),
          'is_admin': req.pathIs('admin/*'),
          'is_admin_slash': req.pathIs('/admin/users/*'),
          'is_users': req.pathIs('users/*'),
          'route_is': req.routeIs('admin.*'),
          'route_is_exact': req.routeIs('admin.users.show'),
          'route_not': req.routeIs('users.*'),
          'token': req.bearerToken(),
        };
      }).name('admin.users.show');
      Route.get('/no-name', (DoxRequest req) async {
        return <String, dynamic>{
          'route_is': req.routeIs('*'),
          'token': req.bearerToken(),
        };
      });

      http.Response res = await http.get(
        Uri.parse('$baseUrl/admin/users/5?tab=info'),
        headers: <String, String>{'authorization': 'Bearer abc.123'},
      );
      Map<String, dynamic> j = jsonDecode(res.body);
      expect(j['path'], '/admin/users/5');
      expect(j['full'], '$baseUrl/admin/users/5?tab=info');
      expect(j['is_admin'], true);
      expect(j['is_admin_slash'], true);
      expect(j['is_users'], false);
      expect(j['route_is'], true);
      expect(j['route_is_exact'], true);
      expect(j['route_not'], false);
      expect(j['token'], 'abc.123');

      res = await http.get(
        Uri.parse('$baseUrl/no-name'),
        headers: <String, String>{'authorization': 'Basic abc'},
      );
      j = jsonDecode(res.body);
      expect(j['route_is'], false);
      expect(j['token'], null);
    });

    test('file and hasFile read an upload', () async {
      Route.post('/request/file', (DoxRequest req) async {
        return <String, dynamic>{
          'file': req.file('photo')?.filename,
          'has': req.hasFile('photo'),
          'has_name': req.hasFile('name'),
          'file_name': req.file('name'),
        };
      });

      http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/request/file'),
      );
      request.fields['name'] = 'dox';
      request.files.add(
        http.MultipartFile.fromBytes('photo', <int>[
          1,
          2,
          3,
        ], filename: 'a.png'),
      );
      http.Response res = await http.Response.fromStream(await request.send());
      Map<String, dynamic> j = jsonDecode(res.body);
      expect(j['file'], 'a.png');
      expect(j['has'], true);
      expect(j['has_name'], false);
      expect(j['file_name'], null);
    });
    test('integer gives the default for NaN, Infinity and 1e400', () async {
      Route.post('/request/integer-bad', (DoxRequest req) async {
        return <String, dynamic>{
          'nan': req.integer('nan', 5),
          'inf': req.integer('inf', 5),
          'big': req.integer('big', 5),
          'big_body': req.integer('big_body', 5),
        };
      });
      http.Response res = await http.post(
        Uri.parse(
          '$baseUrl/request/integer-bad?nan=NaN&inf=Infinity&big=1e400',
        ),
        headers: <String, String>{'content-type': 'application/json'},
        body: '{"big_body": 1e400}',
      );
      expect(res.statusCode, 200);
      Map<String, dynamic> j = jsonDecode(res.body);
      expect(j['nan'], 5);
      expect(j['inf'], 5);
      expect(j['big'], 5);
      expect(j['big_body'], 5);
    });

    test('pathIs is false for a path with a bad escape', () async {
      Route.get('/bad-escape', (DoxRequest req) async {
        // the router gives 404 for `/%ff`, so set the path here
        req.uri = Uri.parse('/bad-escape/%ff');
        return <String, dynamic>{'is': req.pathIs('bad-escape/*')};
      });
      http.Response res = await http.get(Uri.parse('$baseUrl/bad-escape'));
      expect(res.statusCode, 200);
      expect(jsonDecode(res.body)['is'], false);
    });

    test('pathIs is false for a bare % or a bad % code', () async {
      Route.get('/bad-percent', (DoxRequest req) async {
        // Uri.parse turns a bare `%` into `%25`, so use a raw path here
        req.uri = _RawPathUri('/bad-percent/%');
        bool bare = req.pathIs('bad-percent/*');
        req.uri = _RawPathUri('/bad-percent/%zz');
        return <String, dynamic>{'bare': bare, 'bad': req.pathIs('*')};
      });
      http.Response res = await http.get(Uri.parse('$baseUrl/bad-percent'));
      expect(res.statusCode, 200);
      expect(jsonDecode(res.body), <String, dynamic>{
        'bare': false,
        'bad': false,
      });
    });

    test('pathIs cleans the path like the router does', () async {
      Map<String, dynamic> check(DoxRequest req) {
        return <String, dynamic>{
          'admin': req.pathIs('admin'),
          'settings': req.pathIs('admin/settings'),
          'slash_pattern': req.pathIs('/admin//settings/'),
          'wild': req.pathIs('admin/*'),
          'all': req.pathIs('*'),
        };
      }

      Route.get('/admin', check);
      Route.get('/admin/settings', check);

      Future<Map<String, dynamic>> get(String path) async {
        http.Response res = await http.get(Uri.parse('$baseUrl$path'));
        expect(res.statusCode, 200, reason: path);
        return jsonDecode(res.body);
      }

      for (String path in <String>['/admin', '/admin/', '/admin//']) {
        Map<String, dynamic> j = await get(path);
        expect(j['admin'], true, reason: path);
        expect(j['settings'], false, reason: path);
        expect(j['all'], true, reason: path);
      }
      // `/admin/` matched `admin/*` before, and still does
      expect((await get('/admin'))['wild'], false);
      expect((await get('/admin/'))['wild'], true);

      for (String path in <String>[
        '/admin/settings',
        '/admin//settings',
        '/admin/settings/',
      ]) {
        Map<String, dynamic> j = await get(path);
        expect(j['settings'], true, reason: path);
        expect(j['slash_pattern'], true, reason: path);
        expect(j['wild'], true, reason: path);
        expect(j['admin'], false, reason: path);
      }

      // `%61` is `a`, on the router side and on the pathIs side
      expect((await get('/%61dmin'))['admin'], true);
      expect((await get('/%61dmin/'))['admin'], true);
    });

    test('pathIs matches regex characters as plain text', () async {
      Route.get('/files/{name}', (DoxRequest req) async {
        return <String, dynamic>{
          'dot': req.pathIs('files/a.b'),
          'plus': req.pathIs('files/a+b*'),
        };
      });
      http.Response res = await http.get(Uri.parse('$baseUrl/files/a.b'));
      expect(jsonDecode(res.body), <String, dynamic>{
        'dot': true,
        'plus': false,
      });
      res = await http.get(Uri.parse('$baseUrl/files/axb'));
      expect(jsonDecode(res.body)['dot'], false);
      res = await http.get(Uri.parse('$baseUrl/files/a+b.txt'));
      expect(jsonDecode(res.body)['plus'], true);
      res = await http.get(Uri.parse('$baseUrl/files/aab'));
      expect(jsonDecode(res.body)['plus'], false);
    });
  });
}

/// a [Uri] whose path is given as it is, not cleaned like [Uri.parse]
class _RawPathUri implements Uri {
  _RawPathUri(this.path);

  @override
  final String path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

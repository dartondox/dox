import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_response_handler.dart';
import 'package:dox_core/http/request/http_request_body.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

import '../utils/test_app_key.dart';

List<ContentType?> seenTypes = <ContentType?>[];

class PathRouter extends Router {
  @override
  void register() {
    Route.get('api/v1/users', (DoxRequest req) => 'users');
    Route.get(
      'api/v1/users/{id}',
      (DoxRequest req) => 'user ${req.param['id']}',
    );
    Route.get(
      'api/v1/users/{id}/posts/{post}',
      (DoxRequest req) => 'post ${req.param['id']} ${req.param['post']}',
    );
    Route.get(
      'api/v1/tags/{tag?}',
      (DoxRequest req) => 'tag ${req.param['tag']}',
    );
    Route.get(
      'api/files/{path*}',
      (DoxRequest req) => 'file ${req.param['path']}',
    );
    // `.` is a regex mark: it matches any char, as before
    Route.get('api/a.b/{id}', (DoxRequest req) => 'dot ${req.param['id']}');
    Route.get('{lang}/about', (DoxRequest req) => 'about ${req.param['lang']}');
    // a part with text and params in it
    Route.get(
      'mix/v{id}/{name}',
      (DoxRequest req) => 'mix ${req.param['id']} ${req.param['name']}',
    );
    Route.get('mix/v{id}', (DoxRequest req) => 'version ${req.param['id']}');
    Route.get(
      'mix/{a}-{b}',
      (DoxRequest req) => 'pair ${req.param['a']} ${req.param['b']}',
    );
    Route.get(
      'mix/n{id}',
      (DoxRequest req) => 'number ${req.param['id']}',
    ).where('id', '[0-9]+');
    Route.post('types', (DoxRequest req) {
      seenTypes.add(HttpBody.contentTypeOf(req.httpHeaders));
      return req.body;
    });
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(appKey: testAppKey, routers: <Router>[PathRouter()]),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  group('route matching', () {
    test('param routes behind a plain prefix', () async {
      (await client.get('/api/v1/users')).expectBody('users');
      (await client.get('/api/v1/users/5')).expectBody('user 5');
      (await client.get('/api/v1/users/5/')).expectBody('user 5');
      (await client.get('/api/v1/users/5/posts/9')).expectBody('post 5 9');
      (await client.get('/api/v1/users/a%20b')).expectBody('user a b');
    });

    test('a url without the prefix does not match', () async {
      (await client.get('/api/v1/other/5')).expectStatus(404);
      (await client.get('/API/v1/users/5')).expectStatus(404);
      (await client.get('/api/v1/usersx/5')).expectStatus(404);
    });

    test('optional and wildcard params', () async {
      (await client.get('/api/v1/tags')).expectBody('tag null');
      (await client.get('/api/v1/tags/dart')).expectBody('tag dart');
      (await client.get('/api/files/a/b/c.txt')).expectBody('file a/b/c.txt');
    });

    test('regex marks in the plain text work as before', () async {
      (await client.get('/api/a.b/1')).expectBody('dot 1');
      (await client.get('/api/axb/2')).expectBody('dot 2');
    });

    test('a route that starts with a param', () async {
      (await client.get('/en/about')).expectBody('about en');
    });

    test('a part with text and params gives each param its value', () async {
      (await client.get('/mix/v5/bob')).expectBody('mix 5 bob');
      (await client.get('/mix/v5')).expectBody('version 5');
      (await client.get('/mix/x-y')).expectBody('pair x y');
      (await client.get('/mix/x')).expectStatus(404);
      (await client.get('/mix/n42')).expectBody('number 42');
      (await client.get('/mix/nab')).expectStatus(404);
      (await client.get('/mix/v%7Bid%7D')).expectBody('version {id}');
      RouteData route = RouteData(
        method: 'GET',
        path: '/v{id}/{a}-{b?}/{rest*}',
        controllers: <dynamic>[],
      );
      expect(route.paramNames, <String>['id', 'a', 'b', 'rest']);
    });

    test('matchPrefix', () {
      RouteData route(String path) =>
          RouteData(method: 'GET', path: path, controllers: <dynamic>[]);
      expect(route('/api/users/{id}').matchPrefix, '/api/users');
      expect(route('/api/tags/{tag?}').matchPrefix, '/api/tags');
      expect(route('/files/{path*}').matchPrefix, '/files');
      expect(route('/{id}').matchPrefix, isNull);
      expect(route('/a.b/{id}').matchPrefix, isNull);
      expect(route('/api/users').matchPrefix, isNull);
    });

    test('hasSegments: only plain parts and whole required params', () {
      RouteData route(String path) =>
          RouteData(method: 'GET', path: path, controllers: <dynamic>[]);
      expect(route('/users/{id}').hasSegments, isTrue);
      expect(route('/{lang}/about').hasSegments, isTrue);
      expect(route('/a/{b}/c/{d}').hasSegments, isTrue);
      expect(route('/users').hasSegments, isFalse);
      expect(route('/tags/{tag?}').hasSegments, isFalse);
      expect(route('/files/{path*}').hasSegments, isFalse);
      expect(route('/a.b/{id}').hasSegments, isFalse);
      expect(route('/v{id}/x').hasSegments, isFalse);
      expect(route('/{a}{b}').hasSegments, isFalse);
      expect(route('/users/{id}/').hasSegments, isFalse);
      expect(route('users/{id}').hasSegments, isFalse);
      expect(
        (route('/users/{id}')..where('id', '[0-9]+')).hasSegments,
        isFalse,
      );
      expect(route('/users').matchSegments('/users'), isNull);
    });

    test('matchSegments gives the same answer as the regex', () {
      List<String> paths = <String>[
        '/users/{id}',
        '/{lang}/about',
        '/{id}',
        '/a/{b}/c/{d}',
        '/api/v1/users/{user}/posts/{post}',
        '/{a}/{b}/{c}',
      ];
      List<String> urls = <String>[
        '/',
        '/users',
        '/users/5',
        '/users/5/6',
        '/users/5/',
        '/users//5',
        '/users/',
        '/users/a%2Fb',
        '/users/%ff',
        'users/5',
        '',
        '/users/a%20b',
        '/users/ a\nb ',
        '/Users/5',
        '/usersx/5',
        '/user/5',
        '/en/about',
        '/en/about/us',
        '/en/abouts',
        '/x',
        '/a/1/c/2',
        '/a/1/c',
        '/a/1/d/2',
        '/a/1/c/2/3',
        '/api/v1/users/7/posts/9',
        '/api/v1/users/7/posts',
        '/api/v2/users/7/posts/9',
        '/1/2/3',
        '/1/2',
        '/é/about',
      ];
      for (String path in paths) {
        RouteData route = RouteData(
          method: 'GET',
          path: path,
          controllers: <dynamic>[],
        );
        expect(route.hasSegments, isTrue, reason: path);
        for (String url in urls) {
          RegExpMatch? match = route.pattern!.firstMatch(url);
          List<String?>? want = match == null
              ? null
              : <String?>[
                  for (int i = 1; i <= match.groupCount; i++) match.group(i),
                ];
          expect(route.matchSegments(url), want, reason: '$path on $url');
        }
      }
    });
  });

  group('content type', () {
    test('the same header text gives the same parsed type', () async {
      seenTypes.clear();
      for (int i = 0; i < 2; i++) {
        (await client.post(
          '/types',
          body: <String, dynamic>{'a': i},
        )).expectStatus(200).expectJson(<String, dynamic>{'a': i});
      }
      expect(seenTypes, hasLength(2));
      expect(seenTypes[0]!.mimeType, 'application/json');
      expect(identical(seenTypes[0], seenTypes[1]), isTrue);
    });

    test('a parsed type can not be changed', () {
      ContentType type = ContentType.parse('text/plain; charset=utf-8');
      expect(() => type.parameters['x'] = 'y', throwsUnsupportedError);
    });
  });

  group('utf8Bytes', () {
    test('gives the same bytes as utf8.encode', () {
      for (String text in <String>[
        '',
        'hello',
        '<p>ok</p>',
        'café',
        'Ā 中文 🎉',
        'a\uD800',
        '\uDC00b',
      ]) {
        expect(utf8Bytes(text), utf8.encode(text), reason: text);
      }
    });

    test('a String body is sent as UTF-8', () async {
      (await client.get('/api/v1/users/%C3%A9')).expectBody('user é');
    });
  });

  test('RequestId.make gives 32 hex characters', () {
    Set<String> ids = <String>{};
    for (int i = 0; i < 100; i++) {
      String id = RequestId.make();
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
      ids.add(id);
    }
    expect(ids, hasLength(100));
  });
}

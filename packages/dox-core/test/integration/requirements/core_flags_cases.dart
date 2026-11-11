import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

/// sets a header on the response before the route runs
class PresetHeader implements IDoxNextMiddleware {
  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) {
    req.httpRequest.response.headers.set('X-Mode', 'middleware');
    req.httpRequest.response.headers.set('Vary', 'Origin');
    return next();
  }
}

/// sets the content type straight on the response, before the route
class JsonType implements IDoxNextMiddleware {
  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) {
    req.httpRequest.response.headers.contentType = ContentType.json;
    return next();
  }
}

class Reported extends ExceptionHandler {
  final List<Object> errors = <Object>[];

  @override
  void report(Object error, StackTrace stackTrace) => errors.add(error);
}

class FlagsRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[const SessionMiddleware()];

  @override
  void register() {
    Route.post('only', (DoxRequest req) => req.only(<String>['a', 'b']));
    Route.post(
      'has',
      (DoxRequest req) => <String, bool>{
        'empty': req.has('empty'),
        'nothing': req.has('nothing'),
        'missing': req.has('missing'),
        'full': req.has('full'),
      },
    );
    Route.get('text', (DoxRequest req) => '<b>hi</b>');
    Route.middleware(<dynamic>[JsonType()], () {
      Route.get('text-json', (DoxRequest req) => '{"a":1}');
      Route.get('text-json-res', (DoxRequest req) => response('{"a":1}'));
    });
    Route.get(
      'text-typed',
      (DoxRequest req) => response('hi').contentType(ContentType.text),
    );
    Route.post(
      'invalid',
      (DoxRequest req) => req.validateSchema(
        v.object(<String, Schema<Object?>>{
          'email': v.string().email(),
          'name': v.string().min(3),
        }),
      ),
      body: v.object(<String, Schema<Object?>>{'email': v.string()}),
    );
    Route.get('decrypt', (DoxRequest req) => Crypt.decryptString('bad'));
    Route.get(
      'format-error',
      (DoxRequest req) => throw const FormatException('<b>x</b>'),
    );
    Route.get('session-all', (DoxRequest req) => req.session.all());
    Route.get('regenerate', (DoxRequest req) {
      String before = req.session.token;
      req.session.regenerate();
      return <String, bool>{'kept': req.session.token == before};
    });
    Route.get('regenerate-keep', (DoxRequest req) {
      String before = req.session.token;
      req.session.regenerate(keepToken: true);
      return <String, bool>{'kept': req.session.token == before};
    });
    Route.get('invalidate', (DoxRequest req) {
      String before = req.session.token;
      req.session.invalidate();
      return <String, bool>{'kept': req.session.token == before};
    });
  }
}

class HeaderRouter extends Router {
  @override
  String get prefix => 'header';

  @override
  List<dynamic> get middleware => <dynamic>[PresetHeader()];

  @override
  void register() {
    Route.get(
      'flag',
      (DoxRequest req) =>
          response('ok').header('X-Mode', 'r').header('Vary', 'X-Inertia'),
    );
    Route.get(
      'replace',
      (DoxRequest req) => response('ok').header('X-Mode', 'r', replace: true),
    );
    Route.get(
      'add',
      (DoxRequest req) => response('ok').header('X-Mode', 'r', replace: false),
    );
  }
}

/// The tests of every `CoreFlags` item. [flags] is all off or all on, and
/// each test checks the old or the new behavior for it.
void coreFlagTests(CoreFlags flags) {
  late DoxTestClient client;
  Reported handler = Reported();

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        routers: <Router>[FlagsRouter(), HeaderRouter()],
        exceptionHandler: handler,
        flags: flags,
        cache: const CacheConfig(
          defaultStore: 'a',
          stores: <String, Map<String, dynamic>>{
            'a': <String, dynamic>{'driver': 'memory'},
            'b': <String, dynamic>{'driver': 'memory'},
          },
        ),
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  Map<String, String> json = <String, String>{
    'content-type': 'application/json',
    'accept': 'application/json',
  };

  test('Dox().flags is the flags of the config', () {
    expect(Dox().flags, same(flags));
  });

  test('laravelErrors: the 422 body', () async {
    TestResponse res = await client.post(
      '/invalid',
      body: '{"email": "x", "name": "a"}',
      headers: json,
    );
    res.expectStatus(422);
    if (flags.laravelErrors) {
      expect(res.json['message'], contains('(and 1 more error)'));
      expect(res.json['errors'], <String, dynamic>{
        'email': <dynamic>[isA<String>()],
        'name': <dynamic>[isA<String>()],
      });
    } else {
      expect(res.json, <String, dynamic>{
        'email': isA<String>(),
        'name': isA<String>(),
      });
    }
  });

  test('laravelErrors: a ValidationException made by hand', () {
    Object? body = ValidationException(
      message: <String, String>{'title': 'Required'},
    ).toResponse();
    expect(
      body,
      flags.laravelErrors
          ? <String, dynamic>{
              'message': 'Required',
              'errors': <String, dynamic>{
                'title': <String>['Required'],
              },
            }
          : <String, String>{'title': 'Required'},
    );
  });

  test('laravelErrors: the OpenAPI schema of the 422', () {
    Map<String, dynamic> doc = OpenApiDocument(const OpenApiConfig())
        .build(Route().routes)
        .toJson();
    Map<String, dynamic> schema =
        doc['components']['schemas']['ValidationError'];
    if (flags.laravelErrors) {
      expect(schema['required'], <String>['message', 'errors']);
    } else {
      expect(schema['additionalProperties'], <String, dynamic>{
        'type': 'string',
      });
    }
  });

  test('onlyPresent: req.only and missing keys', () async {
    TestResponse res = await client.post(
      '/only',
      body: '{"a": 1}',
      headers: json,
    );
    expect(
      res.json,
      flags.onlyPresent
          ? <String, dynamic>{'a': 1}
          : <String, dynamic>{'a': 1, 'b': null},
    );
  });

  test('hasKeyOnly: req.has', () async {
    TestResponse res = await client.post(
      '/has',
      body: '{"empty": "", "nothing": null, "full": "x"}',
      headers: json,
    );
    expect(res.json, <String, dynamic>{
      'empty': flags.hasKeyOnly,
      'nothing': flags.hasKeyOnly,
      'missing': false,
      'full': true,
    });
  });

  test('cookieDefaults: Path and SameSite', () {
    String cookie = DoxCookie('a', 'b', encrypt: false).get();
    String gone = DoxCookie('a', 'b', encrypt: false).expire();
    String own = DoxCookie(
      'a',
      'b',
      encrypt: false,
      path: '/x',
      sameSite: SameSite.strict,
    ).get();
    for (String line in <String>[cookie, gone]) {
      if (flags.cookieDefaults) {
        expect(line, contains('Path=/'));
        expect(line.toLowerCase(), contains('samesite=lax'));
      } else {
        expect(line, isNot(contains('Path=')));
        expect(line.toLowerCase(), isNot(contains('samesite')));
      }
    }
    expect(own, contains('Path=/x'));
    expect(own.toLowerCase(), contains('samesite=strict'));
  });

  test('htmlStrings: the content type of a string', () async {
    TestResponse res = await client.get('/text');
    expect(
      res.header('content-type'),
      flags.htmlStrings
          ? 'text/html; charset=utf-8'
          : 'text/plain; charset=utf-8',
    );
    expect(res.body, '<b>hi</b>');
    TestResponse typed = await client.get('/text-typed');
    expect(typed.header('content-type'), startsWith('text/plain'));
    // a type a middleware set on the response stays, in both modes
    for (String path in <String>['/text-json', '/text-json-res']) {
      TestResponse res = await client.get(path);
      expect(res.header('content-type'), startsWith('application/json'));
      expect(res.body, '{"a":1}');
    }
  });

  test('htmlStrings: the development error text stays plain', () async {
    Env().env['APP_ENV'] = 'development';
    addTearDown(() => Env().env.remove('APP_ENV'));
    TestResponse res = await client.get('/format-error');
    res.expectStatus(500);
    expect(res.body, contains('<b>x</b>'));
    expect(res.header('content-type'), startsWith('text/plain'));
  });

  test('replaceHeaders: res.header and a value set before', () async {
    String added = (await client.get('/header/add')).header('x-mode')!;
    String replaced = (await client.get('/header/replace')).header('x-mode')!;
    String flag = (await client.get('/header/flag')).header('x-mode')!;
    expect(added, allOf(contains('middleware'), contains('r')));
    expect(replaced, 'r');
    expect(flag, flags.replaceHeaders ? 'r' : added);
    // Vary is a list: the flag never drops the Vary of a middleware
    String vary = (await client.get('/header/flag')).header('vary')!;
    expect(vary, allOf(contains('Origin'), contains('X-Inertia')));
  });

  test(
    'session.regenerate: new token by default, keepToken keeps it',
    () async {
      DoxTestClient browser = client.withSession();
      (await browser.get('/regenerate'))
          .expectJson(<String, dynamic>{'kept': false});
      (await browser.get('/regenerate-keep'))
          .expectJson(<String, dynamic>{'kept': true});
      (await browser.get('/invalidate'))
          .expectJson(<String, dynamic>{'kept': false});
    },
  );

  test('decryptServerError: the status and the report', () async {
    handler.errors.clear();
    TestResponse res = await client.get('/decrypt');
    if (flags.decryptServerError) {
      res.expectStatus(500);
      expect(res.json, <String, dynamic>{
        'code': 'server_error',
        'message': 'Server Error',
      });
      expect(handler.errors.single, isA<DecryptException>());
    } else {
      res.expectStatus(400);
      expect(res.json['code'], 'decrypt_failed');
      expect(handler.errors, isEmpty);
    }
  });

  test(
    'decryptServerError: a bad session cookie is an empty session',
    () async {
      handler.errors.clear();
      (await client
              .withCookies(<String, String>{'dox_session': 'garbage'})
              .get('/session-all'))
          .expectStatus(200)
          .expectJson(<String, dynamic>{});
      expect(handler.errors, isEmpty);
    },
  );

  test('cacheCopies: Cache().store() and tags()', () async {
    await Cache().store('b').put('k', 'in b');
    Cache first = Cache();
    Cache other = first.store('b');
    expect(identical(first, other), !flags.cacheCopies);
    // the first one stays on the default store, or it moved to store b
    expect(await first.get('k'), flags.cacheCopies ? isNull : 'in b');
    expect(await other.get('k'), 'in b');
    Cache tagged = first.tags(<String>['t']);
    expect(identical(first, tagged), !flags.cacheCopies);
  });

  test('a HealthCheck cache check uses its store in both modes', () async {
    expect(await HealthCheck.cache('b')(), isTrue);
  });
}

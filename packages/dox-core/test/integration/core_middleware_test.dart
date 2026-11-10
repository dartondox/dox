import 'dart:async';

import 'package:crypto/crypto.dart' show Hmac, sha256;
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

const String oldKey = 'old-key-old-key-old-key-old-key!';

/// what the error reports saw
List<String?> reportedIds = <String?>[];
List<Object> reportedErrors = <Object>[];

class RecordingHandler extends ExceptionHandler {
  const RecordingHandler();

  @override
  void report(Object error, StackTrace stackTrace) {
    reportedIds.add(ExceptionHandler.requestId);
    reportedErrors.add(error);
  }
}

/// what the terminate steps saw
List<String> terminated = <String>[];

class Track implements IDoxMiddleware, IDoxTerminableMiddleware {
  @override
  dynamic handle(IDoxRequest req) {
    terminated.add('handle');
    return req;
  }

  @override
  void terminate(DoxRequest req, DoxResponse res) {
    terminated.add('terminate ${req.uri.path} ${res.status}');
  }
}

/// a terminate-only middleware, with no handle step
class OnlyEnd implements IDoxTerminableMiddleware {
  @override
  Future<void> terminate(DoxRequest req, DoxResponse res) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    terminated.add('only end');
  }
}

class Broken implements IDoxTerminableMiddleware {
  @override
  void terminate(DoxRequest req, DoxResponse res) {
    throw StateError('terminate broke');
  }
}

bool lateDone = false;

Map<String, dynamic>? logLine;

Map<String, dynamic> keepLine(Map<String, dynamic> line) => logLine = line;

class CoreRouter extends Router {
  @override
  void register() {
    // request id
    Route.get('/id', <dynamic>[
      const RequestId(),
      (DoxRequest req) => req.requestId,
    ]);
    Route.get('/id-strict', <dynamic>[
      const RequestId(trustClient: false),
      (DoxRequest req) => req.requestId,
    ]);
    Route.get('/id-error', <dynamic>[
      const RequestId(),
      (DoxRequest req) => throw StateError('boom'),
    ]);
    Route.get('/no-id', (DoxRequest req) => '${req.requestId}');
    Route.get('/id-log', <dynamic>[
      const RequestId(),
      LogMiddleware(enabled: true, filter: keepLine),
      (DoxRequest req) => 'logged',
    ]);

    // etag
    Route.get('/etag/text', <dynamic>[const ETag(), (DoxRequest req) => 'hi']);
    Route.get('/etag/json', <dynamic>[
      const ETag(),
      (DoxRequest req) => <String, dynamic>{
        'a': 1,
        'b': <int>[1, 2],
      },
    ]);
    Route.get('/etag/own', <dynamic>[
      const ETag(),
      (DoxRequest req) => response('x').header('ETag', '"mine"'),
    ]);
    Route.get('/etag/no-store', <dynamic>[
      const ETag(),
      (DoxRequest req) => response('x').header('Cache-Control', 'no-store'),
    ]);
    Route.get('/etag/created', <dynamic>[
      const ETag(),
      (DoxRequest req) => response('x').statusCode(201),
    ]);
    Route.get('/etag/stream', <dynamic>[
      const ETag(),
      (DoxRequest req) => Stream<List<int>>.value(<int>[104, 105]),
    ]);
    Route.post('/etag/post', <dynamic>[
      const ETag(),
      (DoxRequest req) => 'posted',
    ]);

    // signed urls
    Route.get('/signed/{id}', <dynamic>[
      const ValidateSignature(),
      (DoxRequest req) => 'ok ${req.param['id']}',
    ]).name('signed');
    Route.get('/signed-rel/{id}', <dynamic>[
      const ValidateSignature(absolute: false),
      (DoxRequest req) => 'ok ${req.param['id']}',
    ]).name('signed.rel');

    // timeout
    Route.get('/slow', (DoxRequest req) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      lateDone = true;
      return 'late';
    }).timeout(const Duration(milliseconds: 50));
    Route.get('/slow-throw', <dynamic>[
      const RequestTimeout(Duration(milliseconds: 50)),
      (DoxRequest req) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        throw StateError('too late');
      },
    ]);
    Route.get(
      '/fast',
      (DoxRequest req) => 'fast',
    ).timeout(const Duration(seconds: 5));

    // terminate
    Route.get('/end', <dynamic>[Track(), (DoxRequest req) => 'ended']);
    Route.get('/end-only', <dynamic>[OnlyEnd(), (DoxRequest req) => 'only']);
    Route.get('/end-error', <dynamic>[
      Track(),
      (DoxRequest req) => throw NotFoundHttpException(),
    ]);
    Route.get('/end-broken', <dynamic>[
      Broken(),
      Track(),
      (DoxRequest req) => 'still ok',
    ]);
  }
}

/// wait until [done] is true, at most one second
Future<void> waitFor(bool Function() done) async {
  for (int i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        previousKeys: <String>[oldKey],
        routers: <Router>[CoreRouter()],
        exceptionHandler: const RecordingHandler(),
        logger: const LoggerConfig(enabled: true),
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  setUp(() {
    reportedIds.clear();
    reportedErrors.clear();
    terminated.clear();
  });

  group('RequestId', () {
    test('makes a new id', () async {
      TestResponse res = (await client.get('/id')).expectStatus(200);
      String id = res.header('x-request-id')!;
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(res.body, id);
    });

    test('keeps a safe id from the client', () async {
      (await client.get(
        '/id',
        headers: <String, String>{'X-Request-Id': 'abc-123.x_y'},
      )).expectHeader('x-request-id', 'abc-123.x_y').expectBody('abc-123.x_y');
    });

    test('makes a new id for an unsafe or long one', () async {
      for (String bad in <String>['a b', 'a"b', 'x' * 129]) {
        TestResponse res = await client.get(
          '/id',
          headers: <String, String>{'X-Request-Id': bad},
        );
        expect(res.header('x-request-id'), matches(RegExp(r'^[0-9a-f]{32}$')));
      }
    });

    test('trustClient: false always makes a new id', () async {
      TestResponse res = await client.get(
        '/id-strict',
        headers: <String, String>{'X-Request-Id': 'mine'},
      );
      expect(res.header('x-request-id'), isNot('mine'));
    });

    test('the error report has the id', () async {
      (await client.get(
        '/id-error',
        headers: <String, String>{'X-Request-Id': 'err-1'},
      )).expectStatus(500).expectHeader('x-request-id', 'err-1');
      expect(reportedIds, <String?>['err-1']);
      expect(ExceptionHandler.requestId, isNull);
    });

    test('the log line has the id', () async {
      await client.get(
        '/id-log',
        headers: <String, String>{'X-Request-Id': 'log-1'},
      );
      expect(logLine!['http']['request_id'], 'log-1');
    });

    test('a route without it has no id', () async {
      (await client.get('/no-id'))
          .expectBody('null')
          .expectHeader('x-request-id', isNull);
    });
  });

  group('ETag', () {
    test('a text answer gets a weak ETag, then 304', () async {
      TestResponse first = (await client.get('/etag/text')).expectBody('hi');
      String tag = first.header('etag')!;
      expect(tag, startsWith('W/"'));
      TestResponse second = await client.get(
        '/etag/text',
        headers: <String, String>{'If-None-Match': tag},
      );
      second.expectStatus(304).expectBody('').expectHeader('etag', tag);
    });

    test('JSON keeps its body and type, and matches a list', () async {
      TestResponse first = await client.get('/etag/json');
      first.expectStatus(200).expectJson(<String, dynamic>{
        'a': 1,
        'b': <int>[1, 2],
      });
      expect(first.header('content-type'), contains('application/json'));
      String tag = first.header('etag')!;
      String strong = tag.substring(2);
      (await client.get(
        '/etag/json',
        headers: <String, String>{'If-None-Match': '"other", $strong'},
      )).expectStatus(304);
      (await client.get(
        '/etag/json',
        headers: <String, String>{'If-None-Match': '"other"'},
      )).expectStatus(200);
      (await client.get(
        '/etag/json',
        headers: <String, String>{'If-None-Match': '*'},
      )).expectStatus(304);
    });

    test('a different body gets a different tag', () {
      expect(ETag.of('a'.codeUnits), isNot(ETag.of('b'.codeUnits)));
      expect(ETag.of('ab'.codeUnits), ETag.of('ab'.codeUnits));
    });

    test('does not touch own ETag, no-store, 201, streams, POST', () async {
      (await client.get('/etag/own')).expectHeader('etag', '"mine"');
      (await client.get('/etag/no-store')).expectHeader('etag', isNull);
      (await client.get('/etag/created'))
          .expectStatus(201)
          .expectHeader('etag', isNull);
      (await client.get('/etag/stream'))
          .expectBody('hi')
          .expectHeader('etag', isNull);
      (await client.post('/etag/post')).expectHeader('etag', isNull);
    });
  });

  group('signed urls', () {
    String base() => client.baseUri.toString();

    test('a signed url works', () async {
      String url = Route.signedUrl(
        'signed',
        params: <String, Object>{'id': 5},
        query: <String, Object>{'a': 'x y'},
        baseUrl: base(),
      );
      expect(url, startsWith('${base()}/signed/5?a=x+y&signature='));
      (await client.get(url)).expectStatus(200).expectBody('ok 5');
    });

    test('a changed url, no signature or a bad one gives 403', () async {
      String url = Route.signedUrl(
        'signed',
        params: <String, Object>{'id': 5},
        baseUrl: base(),
      );
      (await client.get(url.replaceFirst('/5?', '/6?'))).expectStatus(403);
      (await client.get('/signed/5')).expectStatus(403);
      (await client.get('/signed/5?signature=abc')).expectStatus(403);
      (await client.get('$url&extra=1')).expectStatus(403);
    });

    test('an expired url gives 403', () async {
      String good = Route.signedUrl(
        'signed',
        params: <String, Object>{'id': 1},
        expires: const Duration(minutes: 5),
        baseUrl: base(),
      );
      expect(good, contains('expires='));
      (await client.get(good)).expectStatus(200);
      String past = Route.signedUrl(
        'signed',
        params: <String, Object>{'id': 1},
        expires: const Duration(minutes: -1),
        baseUrl: base(),
      );
      (await client.get(past)).expectStatus(403);
    });

    test('another host gives 403 for an absolute url', () async {
      String url = Route.signedUrl(
        'signed',
        params: <String, Object>{'id': 5},
        baseUrl: 'https://example.com',
      );
      String path = url.substring('https://example.com'.length);
      (await client.get(path)).expectStatus(403);
    });

    test('a relative url', () async {
      String url = Route.signedUrl(
        'signed.rel',
        params: <String, Object>{'id': 7},
        absolute: false,
      );
      expect(url, startsWith('/signed-rel/7?signature='));
      (await client.get(url)).expectStatus(200).expectBody('ok 7');
    });

    test('a url signed with a previous key still works', () async {
      String path = '/signed-rel/9';
      String signature = Hmac(
        sha256,
        KeyDerivation.derive(oldKey, KeyDerivation.signedUrl),
      ).convert(path.codeUnits).toString();
      (await client.get('$path?signature=$signature')).expectStatus(200);
    });

    test('an absolute url needs a host', () {
      expect(
        () => Route.signedUrl('signed', params: <String, Object>{'id': 1}),
        throwsArgumentError,
      );
    });
  });

  group('timeout', () {
    test('a slow route gives 503, the late result is dropped', () async {
      lateDone = false;
      (await client.get('/slow'))
          .expectStatus(503)
          .expectJson(<String, dynamic>{
            'code': 'request_timeout',
            'message': 'The request took too long',
          });
      await waitFor(() => lateDone);
      expect(lateDone, isTrue);
      (await client.get('/fast')).expectStatus(200).expectBody('fast');
    });

    test('a late error does not crash the server', () async {
      (await client.get('/slow-throw')).expectStatus(503);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      (await client.get('/fast')).expectStatus(200);
    });
  });

  group('terminate', () {
    test('runs after the answer', () async {
      (await client.get('/end')).expectStatus(200).expectBody('ended');
      await waitFor(() => terminated.length == 2);
      expect(terminated, <String>['handle', 'terminate /end 200']);
    });

    test('a terminate-only middleware does not stop the route', () async {
      (await client.get('/end-only')).expectStatus(200).expectBody('only');
      await waitFor(() => terminated.isNotEmpty);
      expect(terminated, <String>['only end']);
    });

    test('gets the error status', () async {
      (await client.get('/end-error')).expectStatus(404);
      await waitFor(() => terminated.length == 2);
      expect(terminated.last, 'terminate /end-error 404');
    });

    test('an error is reported and the next one still runs', () async {
      (await client.get('/end-broken'))
          .expectStatus(200)
          .expectBody('still ok');
      await waitFor(() => terminated.length == 2);
      expect(terminated.last, 'terminate /end-broken 200');
      expect(reportedErrors.single, isA<StateError>());
    });
  });
}

import 'dart:async';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

class TimingRouter extends Router {
  @override
  void register() {
    Route.get('/timed', <dynamic>[
      const ServerTiming(),
      (DoxRequest req) async {
        ServerTiming.add('db', const Duration(milliseconds: 2));
        await Future<void>.delayed(Duration.zero);
        ServerTiming.add('db', const Duration(microseconds: 1500));
        ServerTiming.add(
          'cache',
          const Duration(milliseconds: 1),
          description: 'hit "a"\n',
        );
        await ServerTiming.measure('render', () => 'html');
        return 'ok';
      },
    ]);
    Route.get('/bad-names', <dynamic>[
      const ServerTiming(),
      (DoxRequest req) {
        ServerTiming.add('my db, x;y', const Duration(milliseconds: 1));
        ServerTiming.add('', const Duration(milliseconds: 1));
        for (int i = 0; i < 40; i++) {
          ServerTiming.add('n$i', Duration.zero);
        }
        return 'ok';
      },
    ]);
    Route.get('/error', <dynamic>[
      const ServerTiming(),
      (DoxRequest req) => throw NotFoundHttpException(),
    ]);
    Route.get('/reserved', <dynamic>[
      const ServerTiming(),
      (DoxRequest req) {
        ServerTiming.add('total', const Duration(seconds: 5));
        ServerTiming.add('handler', const Duration(seconds: 5));
        return 'ok';
      },
    ]);
    Route.get('/own-header', <dynamic>[
      const ServerTiming(),
      (DoxRequest req) => response('ok').header('server-timing', 'cdn;dur=1'),
    ]);
    Route.get('/measure-throws', <dynamic>[
      const ServerTiming(),
      (DoxRequest req) async {
        try {
          await ServerTiming.measure<void>('fail', () async {
            await Future<void>.delayed(Duration.zero);
            throw StateError('fail');
          });
        } on StateError {
          return 'caught';
        }
        return 'not caught';
      },
    ]);
    Route.get('/next-only', <dynamic>[
      (DoxRequest req, Next next) => next(),
      (DoxRequest req) => 'next',
    ]);
    Route.get('/plain', (DoxRequest req) {
      ServerTiming.add('db', const Duration(milliseconds: 1));
      return 'plain';
    });
  }
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        routers: <Router>[TimingRouter()],
      ),
    );
  });

  tearDownAll(() async {
    await client.close();
  });

  group('ServerTiming', () {
    test('sends handler, added timings and total', () async {
      TestResponse res = (await client.get('/timed')).expectStatus(200);
      String header = res.header('server-timing')!;
      List<String> parts = header.split(', ');
      expect(parts.first, matches(RegExp(r'^db;dur=3\.50;desc="2 calls"$')));
      expect(parts, contains(r'cache;dur=1.00;desc="hit \"a\""'));
      expect(header, matches(RegExp(r'render;dur=\d+\.\d\d')));
      expect(header, matches(RegExp(r'handler;dur=\d+\.\d\d')));
      expect(parts.last, matches(RegExp(r'^total;dur=\d+\.\d\d$')));
    });

    test('cleans bad names and limits the count', () async {
      TestResponse res = (await client.get('/bad-names')).expectStatus(200);
      List<String> parts = res.header('server-timing')!.split(', ');
      expect(parts.first, 'my_db__x_y;dur=1.00');
      expect(parts.length, ServerTiming.maxNames + 2);
      expect(parts.last, startsWith('total;dur='));
    });

    test('still times an error answer', () async {
      TestResponse res = (await client.get('/error')).expectStatus(404);
      expect(res.header('server-timing'), contains('total;dur='));
    });

    test('no header and no error without the middleware', () async {
      TestResponse res = (await client.get('/plain')).expectStatus(200);
      expect(res.header('server-timing'), isNull);
    });

    test('a user total or handler gets app_ in front', () async {
      TestResponse res = (await client.get('/reserved')).expectStatus(200);
      List<String> parts = res.header('server-timing')!.split(', ');
      expect(parts[0], 'app_total;dur=5000.00');
      expect(parts[1], 'app_handler;dur=5000.00');
      // the built-in times do not get the 5 seconds
      expect(parts[2], matches(RegExp(r'^handler;dur=\d{1,3}\.\d\d$')));
      expect(parts[3], matches(RegExp(r'^total;dur=\d{1,3}\.\d\d$')));
    });

    test('keeps a Server-Timing header the app set', () async {
      TestResponse res = (await client.get('/own-header')).expectStatus(200);
      String header = res.header('server-timing')!;
      expect(header, startsWith('cdn;dur=1, handler;dur='));
      expect(header, contains('total;dur='));
    });

    test('measure adds the time when an async function throws', () async {
      TestResponse res = (await client.get('/measure-throws'))
          .expectStatus(200);
      expect(res.body, 'caught');
      expect(res.header('server-timing'), matches(RegExp(r'fail;dur=\d')));
    });

    test('a next middleware without ServerTiming sends no header', () async {
      TestResponse res = (await client.get('/next-only')).expectStatus(200);
      expect(res.body, 'next');
      expect(res.header('server-timing'), isNull);
    });

    test('add and measure outside a request do nothing', () async {
      ServerTiming.add('db', const Duration(milliseconds: 1));
      expect(await ServerTiming.measure('x', () => 7), 7);
    });
  });
}

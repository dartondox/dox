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

    test('add and measure outside a request do nothing', () async {
      ServerTiming.add('db', const Duration(milliseconds: 1));
      expect(await ServerTiming.measure('x', () => 7), 7);
    });
  });
}

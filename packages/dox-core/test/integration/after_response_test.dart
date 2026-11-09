import 'dart:async';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:test/test.dart';

List<String> log = <String>[];

class AfterRouter extends Router {
  @override
  void register() {
    Route.get('/work', (DoxRequest req) async {
      AfterResponse.run(() => log.add('first'));
      await Future<void>.delayed(Duration.zero);
      // added from a later async step: still the same request
      AfterResponse.run(() => throw StateError('bad work'));
      AfterResponse.run(() => log.add('second'));
      log.add('handler');
      return 'ok';
    });
    Route.get('/slow', (DoxRequest req) {
      // never ends: the client must still get the answer
      AfterResponse.run(() => Completer<void>().future);
      return 'fast';
    });
  }
}

/// waits until [test] is true, for at most one second
Future<void> _until(bool Function() test) async {
  for (int i = 0; i < 100 && !test(); i++) {
    await Future<void>.delayed(Duration(milliseconds: 10));
  }
  expect(test(), isTrue);
}

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    AfterResponse.enable();
    client = await DoxTestClient.start(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        routers: <Router>[AfterRouter()],
      ),
    );
  });

  tearDownAll(() async {
    AfterResponse.disable();
    await client.close();
  });

  setUp(log.clear);

  test('work runs after the answer, in order, past an error', () async {
    (await client.get('/work')).expectStatus(200).expectBody('ok');
    await _until(() => log.length == 3);
    expect(log, <String>['handler', 'first', 'second']);

    // the server still answers after a failed work
    (await client.get('/work')).expectStatus(200);
  });

  test('the client does not wait for the work', () async {
    (await client.get('/slow')).expectStatus(200).expectBody('fast');
  });

  test('outside a request the work runs soon', () async {
    AfterResponse.run(() => log.add('soon'));
    expect(log, isEmpty);
    await _until(() => log.length == 1);
  });
}

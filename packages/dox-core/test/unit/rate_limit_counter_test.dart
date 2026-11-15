import 'dart:isolate';

import 'package:dox_core/middleware/rate_limit_counter.dart';
import 'package:test/test.dart';

/// counts [times] times on the owner [args.first], gives the counts back
Future<List<int>> _countIn(List<Object> args) async {
  SendPort owner = args[0] as SendPort;
  int times = args[1] as int;
  RateLimitCounter.instance.connect(owner);
  List<int> counts = <int>[];
  for (int i = 0; i < times; i++) {
    counts.add(
      await RateLimitCounter.instance.increment('k', Duration(minutes: 1)),
    );
  }
  RateLimitCounter.instance.close();
  return counts;
}

/// counts [times] times on 'cur' and reads 'prev', gives the pairs back
Future<List<List<int>>> _countAndReadIn(List<Object> args) async {
  SendPort owner = args[0] as SendPort;
  int times = args[1] as int;
  RateLimitCounter.instance.connect(owner);
  List<List<int>> pairs = <List<int>>[];
  for (int i = 0; i < times; i++) {
    (int, int) r = await RateLimitCounter.instance.incrementAndRead(
      'cur',
      'prev',
      Duration(minutes: 1),
    );
    pairs.add(<int>[r.$1, r.$2]);
  }
  RateLimitCounter.instance.close();
  return pairs;
}

void main() {
  tearDown(() {
    RateLimitCounter.instance
      ..close()
      ..maxKeys = RateLimitCounter.defaultMaxKeys;
  });

  test('counts in place when not connected', () async {
    RateLimitCounter c = RateLimitCounter.instance;
    expect(await c.increment('a', Duration(minutes: 1)), 1);
    expect(await c.increment('a', Duration(minutes: 1)), 2);
    expect(await c.increment('b', Duration(minutes: 1)), 1);
  });

  test('a key starts again after its ttl', () async {
    RateLimitCounter c = RateLimitCounter.instance;
    expect(await c.increment('t', Duration(milliseconds: 20)), 1);
    expect(await c.increment('t', Duration(milliseconds: 20)), 2);
    await Future<void>.delayed(Duration(milliseconds: 40));
    expect(await c.increment('t', Duration(milliseconds: 20)), 1);
  });

  test('isolates share one count in the owner isolate', () async {
    SendPort owner = RateLimitCounter.instance.port;
    List<List<int>> all = await Future.wait(<Future<List<int>>>[
      for (int i = 0; i < 4; i++)
        Isolate.run(() => _countIn(<Object>[owner, 25])),
    ]);
    List<int> counts = all.expand((List<int> c) => c).toList()..sort();
    // every count from 1 to 100 once: no count was lost or doubled
    expect(counts, List<int>.generate(100, (int i) => i + 1));
    expect(
      await RateLimitCounter.instance.increment('k', Duration(minutes: 1)),
      101,
    );
  });

  test('incrementAndRead reads the other key with no change', () async {
    RateLimitCounter c = RateLimitCounter.instance;
    Duration ttl = Duration(minutes: 1);
    expect(await c.incrementAndRead('x', 'missing', ttl), (1, 0));
    await c.increment('p', ttl);
    await c.increment('p', ttl);
    expect(await c.incrementAndRead('x', 'p', ttl), (2, 2));
    expect(await c.incrementAndRead('x', 'p', ttl), (3, 2));
  });

  test('incrementAndRead from other isolates, one message each', () async {
    RateLimitCounter c = RateLimitCounter.instance;
    for (int i = 0; i < 3; i++) {
      await c.increment('prev', Duration(minutes: 1));
    }
    SendPort owner = c.port;
    List<List<List<int>>> all = await Future.wait(<Future<List<List<int>>>>[
      for (int i = 0; i < 4; i++)
        Isolate.run(() => _countAndReadIn(<Object>[owner, 25])),
    ]);
    List<List<int>> pairs = all.expand((List<List<int>> p) => p).toList();
    List<int> counts = <int>[for (List<int> p in pairs) p[0]]..sort();
    expect(counts, List<int>.generate(100, (int i) => i + 1));
    expect(pairs.every((List<int> p) => p[1] == 3), isTrue);
    expect(await c.incrementAndRead('prev', 'cur', Duration(minutes: 1)), (
      4,
      100,
    ));
  });

  test('the key cap drops expired keys first', () async {
    RateLimitCounter c = RateLimitCounter.instance..maxKeys = 10;
    for (int i = 0; i < 5; i++) {
      await c.increment('short$i', Duration(milliseconds: 10));
    }
    for (int i = 0; i < 5; i++) {
      await c.increment('long$i', Duration(minutes: 1));
    }
    await Future<void>.delayed(Duration(milliseconds: 30));
    expect(await c.increment('long0', Duration(minutes: 1)), 2);
    expect(await c.increment('new', Duration(minutes: 1)), 1);
    // the 5 expired keys made room, no live key was dropped
    expect(c.length, 6);
    expect(await c.increment('long4', Duration(minutes: 1)), 2);
  });

  test('a full map drops the oldest keys, it never grows', () async {
    RateLimitCounter c = RateLimitCounter.instance..maxKeys = 10;
    for (int i = 0; i < 10; i++) {
      await c.increment('k$i', Duration(minutes: 1));
    }
    expect(await c.increment('k9', Duration(minutes: 1)), 2);
    for (int i = 0; i < 100; i++) {
      await c.increment('flood$i', Duration(minutes: 1));
      expect(c.length, lessThanOrEqualTo(10));
    }
    // a new client is counted, not turned away
    expect(await c.increment('newcomer', Duration(minutes: 1)), 1);
    // the oldest key was dropped: it starts again at 1
    expect(await c.increment('k0', Duration(minutes: 1)), 1);
  });

  test('null maxKeys turns the cap off', () async {
    RateLimitCounter c = RateLimitCounter.instance..maxKeys = null;
    for (int i = 0; i < 50; i++) {
      await c.increment('k$i', Duration(minutes: 1));
    }
    expect(c.length, 50);
  });
}

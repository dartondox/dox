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

void main() {
  tearDown(RateLimitCounter.instance.close);

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
}

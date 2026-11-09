import 'package:dox_cache/dox_cache.dart';
import 'package:test/test.dart';

import 'support/cache_contract.dart';
import 'support/driver_harness.dart';
import 'support/fake_clock.dart';

class MemoryHarness implements DriverHarness {
  FakeClock clock = FakeClock();

  @override
  String get name {
    return 'memory';
  }

  @override
  bool get supportsLocks {
    return true;
  }

  @override
  Future<CacheDriver> create() async {
    clock = FakeClock();
    return MemoryDriver(clock: clock);
  }

  @override
  Future<void> advance(Duration duration) async {
    clock.advance(duration);
  }

  @override
  Future<void> close() async {}
}

void main() {
  runCacheContract(MemoryHarness());

  group('memory LRU', () {
    test('removes the least recently used item', () async {
      MemoryDriver driver = MemoryDriver(maxSize: 2);
      CacheStore cache = CacheStore(driver);
      await cache.put('a', 1);
      await cache.put('b', 2);
      expect(await cache.get('a'), 1);
      await cache.put('c', 3);
      expect(driver.length, 2);
      expect(await cache.get('b'), isNull);
      expect(await cache.get('a'), 1);
      expect(await cache.get('c'), 3);
    });

    test('overwrite does not grow the map', () async {
      MemoryDriver driver = MemoryDriver(maxSize: 2);
      CacheStore cache = CacheStore(driver);
      await cache.put('a', 1);
      await cache.put('a', 2);
      await cache.put('b', 3);
      expect(await cache.get('a'), 2);
      expect(driver.length, 2);
    });

    test('expired items are removed on read', () async {
      FakeClock clock = FakeClock();
      MemoryDriver driver = MemoryDriver(clock: clock);
      await driver.put('a', 1, const Duration(seconds: 1));
      clock.advance(const Duration(seconds: 2));
      expect(await driver.get('a'), isNull);
      expect(driver.length, 0);
    });

    test('two drivers do not share data', () async {
      MemoryDriver one = MemoryDriver();
      MemoryDriver two = MemoryDriver();
      await one.put('a', 1, null);
      expect(await two.get('a'), isNull);
    });
  });

  group('memory sweep', () {
    test('removes expired keys that are never read again', () async {
      FakeClock clock = FakeClock();
      MemoryDriver driver = MemoryDriver(clock: clock);
      for (int i = 0; i < 10; i++) {
        await driver.put('old$i', i, const Duration(seconds: 1));
      }
      await driver.lock('job', const Duration(seconds: 1)).get();
      clock.advance(const Duration(seconds: 2));
      for (int i = 0; i < 1000; i++) {
        await driver.put('new$i', i, null);
      }
      expect(driver.length, 1000);
      expect(await driver.get('new0'), 0);
      expect(
        await driver.lock('job', const Duration(seconds: 1)).get(),
        isTrue,
      );
    });

    test('keeps keys that are not expired', () async {
      FakeClock clock = FakeClock();
      MemoryDriver driver = MemoryDriver(clock: clock);
      await driver.put('keep', 1, const Duration(hours: 1));
      for (int i = 0; i < 1000; i++) {
        await driver.put('k$i', i, null);
      }
      expect(await driver.get('keep'), 1);
    });
  });

  group('memory speed', () {
    test('has does not decode the value', () async {
      CacheStore cache = CacheStore(NoGetDriver());
      await cache.put('a', <String, dynamic>{'big': 1});
      expect(await cache.has('a'), isTrue);
      expect(await cache.has('missing'), isFalse);
    });

    test('a tagged cache reads the tag versions once per call', () async {
      CountingDriver driver = CountingDriver();
      TaggedCache tagged = CacheStore(driver).tags(<String>['t']);
      await tagged.putMany(<String, Object?>{'a': 1, 'b': 2, 'c': 3});
      expect(driver.manyCalls, 1);

      driver.manyCalls = 0;
      await tagged.many(<String>['a', 'b', 'c']);
      expect(driver.manyCalls, 2); // the versions, then the values

      driver.manyCalls = 0;
      await tagged.has('a');
      await tagged.pull('a');
      await tagged.remember<int>('r', null, () => 1);
      expect(driver.manyCalls, 3);
    });

    test('reading an item with no expiry does not read the clock', () async {
      CountingClock clock = CountingClock();
      MemoryDriver driver = MemoryDriver(clock: clock);
      await driver.put('a', 1, null);
      clock.calls = 0;
      await driver.get('a');
      await driver.getRaw('a');
      await driver.has('a');
      expect(clock.calls, 0);
    });

    test('expiry is kept as int milliseconds', () async {
      FakeClock clock = FakeClock();
      MemoryEntry entry = MemoryEntry('1', clock.nowMs() + 1000);
      expect(entry.isExpired(clock.nowMs()), isFalse);
      expect(entry.isExpired(clock.nowMs() + 1000), isTrue);
    });
  });

  group('flexible', () {
    late FakeClock clock;
    late CacheStore cache;
    late int calls;

    setUp(() {
      clock = FakeClock();
      cache = CacheStore(MemoryDriver(clock: clock), clock: clock);
      calls = 0;
    });

    Future<int> compute() async {
      calls++;
      return calls;
    }

    Future<int> read() {
      return cache.flexible<int>(
        'f',
        const Duration(seconds: 10),
        const Duration(seconds: 20),
        compute,
      );
    }

    test('fresh value is served with no compute', () async {
      expect(await read(), 1);
      clock.advance(const Duration(seconds: 5));
      expect(await read(), 1);
      expect(calls, 1);
    });

    test('stale value is served and refreshed in the background', () async {
      expect(await read(), 1);
      clock.advance(const Duration(seconds: 15));
      expect(await read(), 1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(calls, 2);
      expect(await read(), 2);
      expect(calls, 2);
    });

    test('only one caller refreshes a stale value', () async {
      await read();
      clock.advance(const Duration(seconds: 15));
      await Future.wait(<Future<int>>[for (int i = 0; i < 5; i++) read()]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(calls, 2);
    });

    test('after fresh + stale the value is computed again', () async {
      expect(await read(), 1);
      clock.advance(const Duration(seconds: 31));
      expect(await read(), 2);
    });

    test('a null stale keeps the value until a refresh replaces it', () async {
      bool down = false;
      Future<int> rates() async {
        if (down) throw StateError('provider down');
        calls++;
        return calls;
      }

      Future<int> readForever() {
        return cache.flexible<int>(
          'forever',
          const Duration(seconds: 10),
          null,
          rates,
        );
      }

      expect(await readForever(), 1);
      down = true;
      clock.advance(const Duration(days: 30));
      // the provider is down: the last good value stays
      expect(await readForever(), 1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await readForever(), 1);
      // let the failed background refresh finish before the provider is back
      await Future<void>.delayed(const Duration(milliseconds: 10));
      down = false;
      expect(await readForever(), 1); // this read starts the refresh
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await readForever(), 2);
    });

    test('decode is used for a cached value', () async {
      List<String> decode(Object? json) {
        return List<String>.from(json as List<dynamic>);
      }

      Future<List<String>> names() {
        return cache.flexible<List<String>>(
          'n',
          const Duration(seconds: 10),
          const Duration(seconds: 10),
          () => <String>['a'],
          decode: decode,
        );
      }

      expect(await names(), <String>['a']);
      expect(await names(), <String>['a']);
    });
  });
}

/// get() throws, so a test can see that has() does not decode.
class NoGetDriver extends MemoryDriver {
  @override
  Future<dynamic> get(String key) {
    throw StateError('get must not be called');
  }
}

/// Counts many() calls. Tagged caches read tag versions with many().
class CountingDriver extends MemoryDriver {
  int manyCalls = 0;

  @override
  Future<Map<String, dynamic>> many(List<String> keys) {
    manyCalls++;
    return super.many(keys);
  }
}

/// Counts how often the time is read.
class CountingClock extends CacheClock {
  int calls = 0;

  @override
  DateTime now() {
    calls++;
    return DateTime.now();
  }
}

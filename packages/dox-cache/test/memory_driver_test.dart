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
}

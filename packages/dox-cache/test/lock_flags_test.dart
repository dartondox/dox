import 'package:dox_cache/dox_cache.dart';
import 'package:test/test.dart';

CacheManager manager(CacheFlags flags) {
  return CacheManager(
    CacheConfig(
      defaultStore: 'memory',
      stores: <String, Map<String, dynamic>>{
        'memory': <String, dynamic>{'driver': 'memory'},
      },
      flags: flags,
    ),
  );
}

void main() {
  const Duration wait = Duration(milliseconds: 50);

  test('flag off: block() with no callback gives false on timeout', () async {
    CacheStore store = manager(const CacheFlags()).store();
    expect(await store.lock('a').get(), isTrue);
    CacheLock other = store.lock('a');
    expect(other.throwOnTimeout, isFalse);
    expect(await other.block<bool>(wait), isFalse);
  });

  test('lockThrows: block() with no callback throws on timeout', () async {
    CacheStore store = manager(const CacheFlags.all()).store();
    expect(await store.lock('a').get(), isTrue);
    CacheLock other = store.lock('a');
    expect(other.throwOnTimeout, isTrue);
    await expectLater(
      other.block<bool>(wait),
      throwsA(
        isA<LockTimeoutException>()
            .having((LockTimeoutException e) => e.name, 'name', 'a')
            .having((LockTimeoutException e) => e.timeout, 'timeout', wait),
      ),
    );
  });

  test('lockThrows: a tagged store and a free lock', () async {
    CacheStore store = manager(const CacheFlags.all()).store();
    CacheLock lock = store.tags(<String>['t']).lock('b');
    expect(lock.throwOnTimeout, isTrue);
    expect(await lock.block<bool>(wait), isTrue);
  });

  test('throwOnTimeout on one lock wins over the flag', () async {
    CacheStore off = manager(const CacheFlags()).store();
    expect(await off.lock('a').get(), isTrue);
    CacheLock strict = off.lock('a')..throwOnTimeout = true;
    await expectLater(
      strict.block<bool>(wait),
      throwsA(isA<LockTimeoutException>()),
    );

    CacheStore on = manager(const CacheFlags.all()).store();
    expect(await on.lock('a').get(), isTrue);
    CacheLock soft = on.lock('a')..throwOnTimeout = false;
    expect(await soft.block<bool>(wait), isFalse);
  });

  test('a store added by hand gets the flags too', () {
    CacheManager m = manager(const CacheFlags.all());
    m.addStore('own', MemoryDriver());
    expect(m.store('own').lock('x').throwOnTimeout, isTrue);
  });
}

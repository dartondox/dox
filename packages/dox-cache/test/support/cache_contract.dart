import 'package:dox_cache/dox_cache.dart';
import 'package:test/test.dart';

import 'driver_harness.dart';

const Duration ttl = Duration(milliseconds: 300);
const Duration pastTtl = Duration(milliseconds: 450);

/// The same tests for every driver.
void runCacheContract(DriverHarness harness, {Object? skip}) {
  group('${harness.name} contract', () {
    late CacheStore cache;

    setUp(() async {
      cache = CacheStore(await harness.create());
    });

    tearDown(() async {
      await harness.close();
    });

    test('put and get a string', () async {
      await cache.put('name', 'dox');
      expect(await cache.get('name'), 'dox');
    });

    test('keeps JSON types', () async {
      Map<String, dynamic> value = <String, dynamic>{
        'list': <dynamic>[1, 'a', true, null],
        'num': 1.5,
        'int': 3,
        'bool': false,
        'text': 'line\r\nbreak "quoted"',
      };
      await cache.put('json', value);
      expect(await cache.get('json'), value);
      await cache.put('list', <int>[1, 2]);
      expect(await cache.get('list'), <int>[1, 2]);
    });

    test('a stored map is a copy', () async {
      Map<String, dynamic> value = <String, dynamic>{'a': 1};
      await cache.put('copy', value);
      value['a'] = 2;
      expect(await cache.get('copy'), <String, dynamic>{'a': 1});
    });

    test('non JSON value throws', () async {
      await expectLater(cache.put('bad', DateTime(2026)), throwsA(anything));
    });

    test('missing key gives null or default', () async {
      expect(await cache.get('missing'), isNull);
      expect(await cache.get('missing', 'fallback'), 'fallback');
      expect(await cache.has('missing'), isFalse);
    });

    test('has and forget', () async {
      await cache.put('a', 1);
      expect(await cache.has('a'), isTrue);
      expect(await cache.forget('a'), isTrue);
      expect(await cache.forget('a'), isFalse);
      expect(await cache.has('a'), isFalse);
    });

    test('ttl expires', () async {
      await cache.put('short', 'x', ttl);
      expect(await cache.get('short'), 'x');
      await harness.advance(pastTtl);
      expect(await cache.get('short'), isNull);
    });

    test('forever and null ttl do not expire', () async {
      await cache.forever('f', 'x');
      await cache.put('n', 'y');
      await harness.advance(pastTtl);
      expect(await cache.get('f'), 'x');
      expect(await cache.get('n'), 'y');
    });

    test('zero ttl removes the key', () async {
      await cache.put('z', 'x');
      await cache.put('z', 'y', Duration.zero);
      expect(await cache.has('z'), isFalse);
    });

    test('add only stores when missing', () async {
      expect(await cache.add('once', 1, ttl), isTrue);
      expect(await cache.add('once', 2, ttl), isFalse);
      expect(await cache.get('once'), 1);
      await harness.advance(pastTtl);
      expect(await cache.add('once', 3), isTrue);
      expect(await cache.get('once'), 3);
    });

    test('increment and decrement', () async {
      expect(await cache.increment('count'), 1);
      expect(await cache.increment('count', 5), 6);
      expect(await cache.decrement('count', 2), 4);
      expect(await cache.decrement('other'), -1);
      expect(await cache.get('count'), 4);
    });

    test('increment keeps the ttl', () async {
      await cache.put('hits', 1, ttl);
      expect(await cache.increment('hits'), 2);
      await harness.advance(pastTtl);
      expect(await cache.get('hits'), isNull);
    });

    test('increment on text throws', () async {
      await cache.put('word', 'abc');
      await expectLater(cache.increment('word'), throwsA(anything));
    });

    test('many and putMany', () async {
      await cache.putMany(<String, Object?>{'a': 1, 'b': 'two'}, ttl);
      expect(await cache.many(<String>['a', 'b', 'c']), <String, dynamic>{
        'a': 1,
        'b': 'two',
        'c': null,
      });
      await harness.advance(pastTtl);
      expect(await cache.many(<String>['a']), <String, dynamic>{'a': null});
    });

    test('pull gets and removes', () async {
      await cache.put('p', 'v');
      expect(await cache.pull('p'), 'v');
      expect(await cache.has('p'), isFalse);
      expect(await cache.pull('p', 'd'), 'd');
    });

    test('remember runs compute once', () async {
      int calls = 0;
      Future<int> compute() async {
        calls++;
        return 42;
      }

      expect(await cache.remember<int>('r', ttl, compute), 42);
      expect(await cache.remember<int>('r', ttl, compute), 42);
      expect(calls, 1);
      await harness.advance(pastTtl);
      expect(await cache.remember<int>('r', ttl, compute), 42);
      expect(calls, 2);
    });

    test('rememberForever', () async {
      Map<String, dynamic> value = await cache.rememberForever(
        'rf',
        () => <String, dynamic>{'id': 1},
      );
      expect(value, <String, dynamic>{'id': 1});
      await harness.advance(pastTtl);
      expect(await cache.get('rf'), <String, dynamic>{'id': 1});
    });

    test('flush removes everything', () async {
      await cache.put('a', 1);
      await cache.put('b', 2);
      await cache.flush();
      expect(await cache.has('a'), isFalse);
      expect(await cache.has('b'), isFalse);
    });

    test('tags flush only tagged items', () async {
      await cache.put('plain', 1);
      await cache.tags(<String>['users']).put('u1', 'ann');
      await cache.tags(<String>['posts']).put('p1', 'hello');
      expect(await cache.tags(<String>['users']).get('u1'), 'ann');
      expect(await cache.get('u1'), isNull);

      await cache.tags(<String>['users']).flush();
      expect(await cache.tags(<String>['users']).get('u1'), isNull);
      expect(await cache.tags(<String>['posts']).get('p1'), 'hello');
      expect(await cache.get('plain'), 1);
    });

    group('locks', () {
      test('only one owner holds the lock', () async {
        CacheLock first = cache.lock('job', const Duration(seconds: 5));
        CacheLock second = cache.lock('job', const Duration(seconds: 5));
        expect(await first.get(), isTrue);
        expect(await second.get(), isFalse);
        expect(await second.release(), isFalse);
        expect(await first.release(), isTrue);
        expect(await second.get(), isTrue);
        await second.release();
      });

      test('same owner token can release', () async {
        CacheLock first = cache.lock('job2', const Duration(seconds: 5));
        expect(await first.get(), isTrue);
        CacheLock again = cache.lock(
          'job2',
          const Duration(seconds: 5),
          first.owner,
        );
        expect(await again.release(), isTrue);
      });

      test('lock expires after ttl', () async {
        CacheLock first = cache.lock('job3', ttl);
        expect(await first.get(), isTrue);
        await harness.advance(pastTtl);
        expect(await cache.lock('job3', ttl).get(), isTrue);
      });

      test('block waits for release', () async {
        CacheLock first = cache.lock('job4', const Duration(seconds: 5));
        expect(await first.get(), isTrue);
        CacheLock second = cache.lock('job4', const Duration(seconds: 5));
        expect(await second.block(const Duration(milliseconds: 120)), isFalse);
        Future<void>.delayed(
          const Duration(milliseconds: 80),
          first.release,
        ).ignore();
        expect(await second.block(const Duration(seconds: 2)), isTrue);
        await second.release();
      });
    }, skip: skip ?? (harness.supportsLocks ? null : 'driver has no locks'));
  }, skip: skip);
}

import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../integration/requirements/config/app.dart';

void main() {
  group('Cache |', () {
    setUpAll(() async {
      Directory storage = Directory('${Directory.current.path}/storage/');
      if (storage.existsSync()) {
        storage.deleteSync(recursive: true);
      }
      Dox().initialize(config);
    });

    test('put', () async {
      await Cache().store('file').put('name', 'Dox');
      String? value = await Cache().get('name');
      expect(value, 'Dox');
    });

    test('put with duration', () async {
      await Cache().put('delay', 'Dox', duration: Duration(microseconds: 1));
      await Future<dynamic>.delayed(Duration(milliseconds: 1));
      String? value = await Cache().get('delay');
      expect(value, null);
    });

    test('many and putMany', () async {
      await Cache().putMany(<String, Object?>{'m1': 'a', 'm2': 2});
      expect(await Cache().many(<String>['m1', 'm2', 'm3']), <String, dynamic>{
        'm1': 'a',
        'm2': 2,
        'm3': null,
      });
    });

    test('get', () async {
      await Cache().forget('name');
      String? value2 = await Cache().get('name');
      expect(value2, null);
    });

    test('has', () async {
      await Cache().put('exist-key', 'Dox');
      bool value = await Cache().has('exist-key');
      expect(value, true);

      bool value2 = await Cache().has('non-exist-key');
      expect(value2, false);
    });

    test('with tag', () async {
      await Cache().tag('ABC').put('name', 'ABC Dox');
      String? value = await Cache().tag('ABC').get('name');
      expect(value, 'ABC Dox');

      await Cache().tag('ABC').flush();

      String? value2 = await Cache().tag('ABC').get('name');
      expect(value2, null);
    });

    test('json', () async {
      await Cache().forever(
        'student',
        jsonEncode(<String, dynamic>{'name': 'John', 'age': 16}),
      );
      String? value = await Cache().get('student');
      Map<String, dynamic> data = jsonDecode(value!);
      expect(data['name'], 'John');
      expect(data['age'], 16);
    });

    test('remember with decode gives a typed list on a hit too', () async {
      Future<List<String>> names() {
        return Cache()
            .store('memory')
            .remember<List<String>>(
              'typed-names',
              null,
              () => <String>['a', 'b'],
              decode: (Object? json) => (json as List<dynamic>).cast<String>(),
            );
      }

      expect(await names(), <String>['a', 'b']);
      expect(await names(), <String>['a', 'b']);
    });

    test('touch and flexible reach the store', () async {
      Cache memory = Cache().store('memory');
      await memory.put('touch-me', 1);
      expect(
        await memory.touch('touch-me', duration: Duration(minutes: 1)),
        isTrue,
      );
      expect(await memory.touch('not-there'), isFalse);
      int runs = 0;
      Future<int> stats() => memory.flexible<int>(
        'stats',
        Duration(minutes: 1),
        Duration(minutes: 5),
        () => ++runs,
      );
      expect(await stats(), 1);
      expect(await stats(), 1);
      expect(runs, 1);
    });
  });

  group('Cache.withAppPrefix |', () {
    CacheConfig config = CacheConfig(
      defaultStore: 'redis',
      stores: <String, Map<String, dynamic>>{
        'redis': <String, dynamic>{'driver': 'redis'},
        'own': <String, dynamic>{'driver': 'redis', 'prefix': 'mine:'},
        'file': <String, dynamic>{'driver': 'file'},
      },
    );

    test('a Redis store with no prefix gets the app name', () {
      CacheConfig out = Cache.withAppPrefix(config, ' My Shop! ');
      expect(out.stores['redis']!['prefix'], 'my_shop_cache:');
      expect(out.stores['redis']!['driver'], 'redis');
      expect(out.defaultStore, 'redis');
    });

    test('a given prefix and other drivers stay as they are', () {
      CacheConfig out = Cache.withAppPrefix(config, 'shop');
      expect(out.stores['own']!['prefix'], 'mine:');
      expect(out.stores['file']!.containsKey('prefix'), isFalse);
    });

    test('no app name keeps the stores', () {
      CacheConfig result = Cache.withAppPrefix(config, '  ');
      expect(identical(result.stores, config.stores), isTrue);
      expect(result.defaultStore, config.defaultStore);
    });

    test('no app name and an encrypter gives the same config', () {
      CacheConfig own = CacheConfig(
        defaultStore: 'redis',
        stores: config.stores,
        encrypter: const CryptCacheEncrypter(),
      );
      expect(identical(Cache.withAppPrefix(own, '  '), own), isTrue);
    });

    test('the config gets the APP_KEY encrypter when it has none', () {
      expect(
        Cache.withAppPrefix(config, 'x').encrypter,
        isA<CryptCacheEncrypter>(),
      );
    });
  });
}

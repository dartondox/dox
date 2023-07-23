import 'dart:convert';

import 'package:dox_core/cache/drivers/redis/redis_cache_driver.dart';
import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../integration/requirements/config/app.dart';

Config config = Config();

void main() {
  group('Redis Cache |', () {
    setUpAll(() async {
      config.cacheStore = CacheStore.redis;
      config.serverPort = 50011;
      Dox().initialize(config);
    });

    tearDownAll(() async {
      await Cache().flush();
    });

    test('put with driver', () async {
      await Cache()
          .driver(RedisCacheDriver(tag: 'dox'))
          .put('put-with-driver', 'Dox');
      String? value = await Cache()
          .driver(RedisCacheDriver(tag: 'dox'))
          .get('put-with-driver');
      expect(value, 'Dox');
    });

    test('put', () async {
      await Cache().put('name', 'Dox');
      String? value = await Cache().get('name');
      expect(value, 'Dox');
    });

    test('forget', () async {
      await Cache().put('forget', 'Dox');
      await Cache().forget('forget');
      String? value = await Cache().get('forget');
      expect(value, null);
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

    test('store', () async {
      await Cache().store(CacheStore.file).put('name', 'Dox');
      String? value = await Cache().get('name');
      expect(value, 'Dox');
    });

    test('json', () async {
      await Cache().forever(
        'student',
        jsonEncode(<String, dynamic>{
          'name': 'John',
          'age': 16,
        }),
      );
      String? value = await Cache().get('student');
      Map<String, dynamic> data = jsonDecode(value!);
      expect(data['name'], 'John');
      expect(data['age'], 16);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:dox_core/cache/cache_driver.dart';
import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../integration/requirements/config/app.dart';

Config config = Config();

void main() {
  group('Cache |', () {
    setUpAll(() async {
      Directory storage = Directory('${Directory.current.path}/storage/');
      storage.deleteSync(recursive: true);
      config.serverPort = 50011;
      await Dox().initialize(config);
    });

    test('put', () {
      Cache().put('name', 'Dox');
      String? value = Cache().get('name');
      expect(value, 'Dox');
    });

    test('get', () {
      Cache().store(CacheStore.systemDefault).forget('name');
      String? value2 = Cache().get('name');
      expect(value2, null);
    });

    test('has', () {
      Cache().put('exist-key', 'Dox');
      bool value = Cache().has('exist-key');
      expect(value, true);

      bool value2 = Cache().has('non-exist-key');
      expect(value2, false);
    });

    test('with tag', () {
      Cache().tag('ABC').put('name', 'ABC Dox');
      String? value = Cache().tag('ABC').get('name');
      expect(value, 'ABC Dox');

      Cache().tag('ABC').flush();

      String? value2 = Cache().tag('ABC').get('name');
      expect(value2, null);
    });

    test('store', () {
      Cache().store(CacheStore.file).put('name', 'Dox');
      String? value = Cache().get('name');
      expect(value, 'Dox');
    });

    test('json', () {
      Cache().forever(
        'student',
        jsonEncode(<String, dynamic>{
          'name': 'John',
          'age': 16,
        }),
      );
      String? value = Cache().get('student');
      Map<String, dynamic> data = jsonDecode(value!);
      expect(data['name'], 'John');
      expect(data['age'], 16);
    });
  });
}

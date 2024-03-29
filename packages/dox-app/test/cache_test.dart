import 'dart:convert';
import 'dart:io';

import 'package:dox_app/config/app.dart';
import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('Cache |', () {
    setUpAll(() async {
      Directory storage = Directory('${Directory.current.path}/storage/');
      if (storage.existsSync()) {
        storage.deleteSync(recursive: true);
      }
      Dox().initialize(appConfig);
    });

    test('put', () async {
      await Cache().put('name', 'Dox');
      String? value = await Cache().get('name');
      expect(value, 'Dox');
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

    test('store', () async {
      await Cache().put('name', 'Dox');
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

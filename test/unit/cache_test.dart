import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../integration/requirements/config/app.dart';

Config config = Config();

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

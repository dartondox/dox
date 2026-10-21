import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dox_cache/dox_cache.dart';
import 'package:test/test.dart';

import 'support/cache_contract.dart';
import 'support/driver_harness.dart';
import 'support/fake_clock.dart';

class FileHarness implements DriverHarness {
  FakeClock clock = FakeClock();
  Directory? directory;

  @override
  String get name {
    return 'file';
  }

  @override
  bool get supportsLocks {
    return false;
  }

  @override
  Future<CacheDriver> create() async {
    clock = FakeClock();
    directory = await Directory.systemTemp.createTemp('dox_cache_test_');
    return FileDriver(directory: directory, clock: clock);
  }

  @override
  Future<void> advance(Duration duration) async {
    clock.advance(duration);
  }

  @override
  Future<void> close() async {
    await directory?.delete(recursive: true);
  }
}

void main() {
  runCacheContract(FileHarness());

  group('file driver', () {
    late Directory directory;
    late FakeClock clock;
    late FileDriver driver;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('dox_cache_file_');
      clock = FakeClock();
      driver = FileDriver(directory: directory, prefix: 'p:', clock: clock);
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    List<String> fileNames() {
      List<String> names = <String>[];
      for (FileSystemEntity entity in directory.listSync()) {
        names.add(entity.uri.pathSegments.last);
      }
      return names;
    }

    test('file name is sha256 of prefix and key', () async {
      await driver.put('user/1?', 'x', null);
      String hash = sha256.convert(utf8.encode('p:user/1?')).toString();
      expect(fileNames(), <String>[hash]);
    });

    test('file holds value and expiry as JSON', () async {
      await driver.put(
          'a', <String, dynamic>{'b': 1}, const Duration(seconds: 10));
      Map<String, dynamic> data =
          jsonDecode(await driver.fileFor('a').readAsString())
              as Map<String, dynamic>;
      expect(data['value'], <String, dynamic>{'b': 1});
      expect(data['expires_at'],
          clock.now().add(const Duration(seconds: 10)).millisecondsSinceEpoch);
    });

    test('no temp files are left after writes', () async {
      for (int i = 0; i < 20; i++) {
        await driver.put('k$i', i, null);
      }
      expect(fileNames().where(_isTemp), isEmpty);
      expect(fileNames().length, 20);
    });

    test('parallel writes never leave a broken file', () async {
      List<Future<void>> writes = <Future<void>>[];
      for (int i = 0; i < 30; i++) {
        writes.add(driver.put('same', 'value $i' * 200, null));
      }
      await Future.wait(writes);
      String value = await driver.get('same') as String;
      expect(value, startsWith('value '));
      expect(fileNames(), hasLength(1));
    });

    test('expired file is deleted on read', () async {
      await driver.put('a', 1, const Duration(seconds: 1));
      clock.advance(const Duration(seconds: 2));
      expect(await driver.get('a'), isNull);
      expect(fileNames(), isEmpty);
    });

    test('broken file is a miss and is deleted', () async {
      await driver.fileFor('a').writeAsString('{not json');
      expect(await driver.get('a'), isNull);
      expect(fileNames(), isEmpty);
    });

    test('flush clears the folder', () async {
      await driver.put('a', 1, null);
      await File('${directory.path}/other.txt').writeAsString('x');
      await driver.flush();
      expect(fileNames(), isEmpty);
    });

    test('two drivers on one folder share data', () async {
      FileDriver other = FileDriver(directory: directory, prefix: 'p:');
      await driver.put('shared', 'yes', null);
      expect(await other.get('shared'), 'yes');
    });

    test('lock is not supported', () {
      expect(() => driver.lock('x', null), throwsUnsupportedError);
    });
  });
}

bool _isTemp(String name) {
  return name.endsWith('.tmp');
}

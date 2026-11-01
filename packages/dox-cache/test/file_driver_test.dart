import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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
    return true;
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

/// Runs in another isolate: [count] increments on one key.
Future<void> incrementInIsolate(String path, int count) async {
  FileDriver driver = FileDriver(directory: Directory(path));
  for (int i = 0; i < count; i++) {
    await driver.increment('hits', 1);
  }
}

/// Runs in another isolate: one add on one key.
Future<bool> addInIsolate(String path) async {
  return await FileDriver(directory: Directory(path)).add('once', 1, null);
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
      if (!driver.storeDirectory.existsSync()) {
        return names;
      }
      for (FileSystemEntity entity in driver.storeDirectory.listSync()) {
        names.add(entity.uri.pathSegments.last);
      }
      return names;
    }

    test('file is sha256 of prefix and key, in a folder per prefix', () async {
      await driver.put('user/1?', 'x', null);
      String hash = sha256.convert(utf8.encode('p:user/1?')).toString();
      String folder = sha256
          .convert(utf8.encode('p:'))
          .toString()
          .substring(0, 16);
      expect(driver.storeDirectory.path, endsWith(folder));
      expect(fileNames(), <String>[hash]);
    });

    test('file holds value and expiry as JSON', () async {
      await driver.put('a', <String, dynamic>{
        'b': 1,
      }, const Duration(seconds: 10));
      Map<String, dynamic> data = jsonDecode(
        await driver.fileFor('a').readAsString(),
      ) as Map<String, dynamic>;
      expect(data['value'], <String, dynamic>{'b': 1});
      expect(
        data['expires_at'],
        clock.now().add(const Duration(seconds: 10)).millisecondsSinceEpoch,
      );
    });

    test('reads files in the same JSON format as the old code', () async {
      await driver.storeDirectory.create(recursive: true);
      await driver
          .fileFor('old')
          .writeAsString('{"value":{"a":[1,"b"]},"expires_at":null}');
      expect(await driver.get('old'), <String, dynamic>{
        'a': <dynamic>[1, 'b'],
      });
      expect(await driver.getRaw('old'), '{"a":[1,"b"]}');
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

    test('an expired file is a miss, but a read does not delete it', () async {
      await driver.put('a', 1, const Duration(seconds: 1));
      clock.advance(const Duration(seconds: 2));
      expect(await driver.get('a'), isNull);
      expect(fileNames(), hasLength(1));
    });

    test('a broken file is a miss, but a read does not delete it', () async {
      await driver.storeDirectory.create(recursive: true);
      await driver.fileFor('a').writeAsString('{not json');
      expect(await driver.get('a'), isNull);
      expect(fileNames(), hasLength(1));
    });

    test('prune deletes expired and broken files only', () async {
      await driver.put('old', 1, const Duration(seconds: 1));
      await driver.put('keep', 2, null);
      await driver.fileFor('broken').writeAsString('{not json');
      clock.advance(const Duration(seconds: 2));
      expect(await driver.prune(), 2);
      expect(fileNames(), hasLength(1));
      expect(await driver.get('keep'), 2);
    });

    test('writes prune expired files by themselves', () async {
      FileDriver pruning = FileDriver(
        directory: directory,
        clock: clock,
        pruneEvery: 3,
      );
      await pruning.put('old', 1, const Duration(seconds: 1));
      clock.advance(const Duration(seconds: 2));
      await pruning.put('a', 2, null);
      expect(pruning.fileFor('old').existsSync(), isTrue);
      await pruning.put('b', 3, null);
      for (int i = 0; i < 100 && pruning.fileFor('old').existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(pruning.fileFor('old').existsSync(), isFalse);
      expect(await pruning.get('a'), 2);
    });

    test('flush clears only the folder of this prefix', () async {
      FileDriver other = FileDriver(directory: directory, prefix: 'q:');
      await driver.put('a', 1, null);
      await other.put('a', 2, null);
      await File('${directory.path}/other.txt').writeAsString('x');
      await driver.flush();
      expect(fileNames(), isEmpty);
      expect(await other.get('a'), 2);
      expect(File('${directory.path}/other.txt').existsSync(), isTrue);
    });

    test('flush keeps temp files of writes that are running', () async {
      await driver.put('a', 1, null);
      File temp = File('${driver.fileFor('b').path}.abc.tmp');
      await temp.writeAsString('{"value":2,"expires_at":null}');
      await driver.flush();
      expect(temp.existsSync(), isTrue);
      await temp.rename(driver.fileFor('b').path);
      expect(await driver.get('b'), 2);
    });

    test('two drivers on one folder share data', () async {
      FileDriver other = FileDriver(directory: directory, prefix: 'p:');
      await driver.put('shared', 'yes', null);
      expect(await other.get('shared'), 'yes');
    });

    test('lock is shared by two drivers on one folder', () async {
      FileDriver other = FileDriver(
        directory: directory,
        prefix: 'p:',
        clock: clock,
      );
      CacheLock first = driver.lock('job', const Duration(seconds: 5));
      expect(await first.get(), isTrue);
      expect(
        await other.lock('job', const Duration(seconds: 5)).get(),
        isFalse,
      );
      expect(await first.release(), isTrue);
      expect(await other.lock('job', const Duration(seconds: 5)).get(), isTrue);
    });

    test('remember with lock runs compute once across two drivers', () async {
      CacheStore one = CacheStore(driver);
      CacheStore two = CacheStore(
        FileDriver(directory: directory, prefix: 'p:', clock: clock),
      );
      int calls = 0;
      Future<int> compute() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return 5;
      }

      List<int> values = await Future.wait(<Future<int>>[
        one.remember<int>('r', null, compute, lock: true),
        two.remember<int>('r', null, compute, lock: true),
      ]);
      expect(values, <int>[5, 5]);
      expect(calls, 1);
    });

    test('increment is safe across isolates', () async {
      String path = directory.path;
      await Future.wait(<Future<void>>[
        for (int i = 0; i < 4; i++)
          Isolate.run(() => incrementInIsolate(path, 10)),
      ]);
      expect(await FileDriver(directory: directory).get('hits'), 40);
    });

    test('add is safe across isolates', () async {
      String path = directory.path;
      List<bool> added = await Future.wait(<Future<bool>>[
        for (int i = 0; i < 4; i++) Isolate.run(() => addInIsolate(path)),
      ]);
      expect(added.where(_isTrue), hasLength(1));
    });
  });
}

bool _isTemp(String name) {
  return name.endsWith('.tmp');
}

bool _isTrue(bool value) {
  return value;
}

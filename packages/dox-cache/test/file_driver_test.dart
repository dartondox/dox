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

    test('prune_every is 0 by default, the option sets it', () {
      expect(driver.pruneEvery, 0);
      FileDriver built = const FileDriverFactory().create(<String, dynamic>{
        'path': directory.path,
        'prune_every': 50,
      }) as FileDriver;
      expect(built.pruneEvery, 50);
    });

    test('fsync is on by default, fsync: false turns it off', () {
      expect(driver.fsync, isTrue);
      FileDriver built = const FileDriverFactory().create(<String, dynamic>{
        'path': directory.path,
        'fsync': false,
      }) as FileDriver;
      expect(built.fsync, isFalse);
      expect(
        (const FileDriverFactory().create(<String, dynamic>{
          'path': directory.path,
        }) as FileDriver).fsync,
        isTrue,
      );
    });

    test('values work with fsync off', () async {
      FileDriver fast = FileDriver(directory: directory, fsync: false);
      await fast.put('a', 1, null);
      expect(await fast.add('b', 2, null), isTrue);
      expect(await fast.increment('a', 2), 3);
      expect(await fast.get('b'), 2);
    });

    test('a failed write leaves no temp file', () async {
      // a folder with a file in it where the value file goes: the rename
      // fails
      await Directory(driver.fileFor('a').path).create(recursive: true);
      await File('${driver.fileFor('a').path}/x').writeAsString('x');
      await expectLater(
        driver.put('a', 1, null),
        throwsA(isA<FileSystemException>()),
      );
      expect(fileNames().where(_isTemp), isEmpty);
    });

    test('prune deletes old temp files and free lock files', () async {
      await driver.put('keep', 1, null);
      String owner = CacheLock.randomOwner();
      File oldTemp = File('${driver.fileFor('a').path}.$owner.tmp');
      await oldTemp.writeAsString('x');
      await oldTemp.setLastModified(_hoursAgo(2));
      File newTemp = File('${driver.fileFor('b').path}.$owner.tmp');
      await newTemp.writeAsString('x');
      CacheLock expired = driver.lock('old', const Duration(seconds: 1));
      expect(await expired.get(), isTrue);
      clock.advance(const Duration(seconds: 2));
      CacheLock held = driver.lock('held', const Duration(minutes: 1));
      expect(await held.get(), isTrue);
      CacheLock forever = driver.lock('forever', null);
      expect(await forever.get(), isTrue);

      expect(await driver.prune(), 0);
      expect(oldTemp.existsSync(), isFalse);
      expect(newTemp.existsSync(), isTrue);
      // the expired lock file is gone, the held ones stay
      expect(fileNames().where(_isLock), hasLength(2));
      expect(await held.release(), isTrue);
      expect(await forever.release(), isTrue);
      expect(await driver.get('keep'), 1);
    });

    test('prune never touches files the cache did not make', () async {
      await driver.put('keep', 1, null);
      Directory folder = driver.storeDirectory;
      Map<String, String> foreign = <String, String>{
        'notes.lock': '[1, 2]',
        'readme.lock': 'not json',
        'data.json': '{}',
        'README': 'x',
        'old.tmp': 'x',
        '${driver.fileFor('x').path.split('/').last}.mv': '{}',
      };
      for (MapEntry<String, String> file in foreign.entries) {
        File made = File('${folder.path}/${file.key}');
        await made.writeAsString(file.value);
        await made.setLastModified(_hoursAgo(2));
      }
      // a lock file of the cache with JSON that is not a map: no error
      File odd = File(
        '${driver.fileFor('odd').path}${CacheConstants.fileLockSuffix}',
      );
      await odd.writeAsString('[1]');
      await odd.setLastModified(_hoursAgo(2));

      expect(await driver.prune(), 0);
      for (String name in foreign.keys) {
        expect(File('${folder.path}/$name').existsSync(), isTrue);
      }
      // an old lock file with no owner in it is free, so it goes
      expect(odd.existsSync(), isFalse);
      expect(await driver.get('keep'), 1);
    });

    test('a value file with JSON that is not a map is a miss', () async {
      await driver.storeDirectory.create(recursive: true);
      await driver.fileFor('list').writeAsString('[1, 2]');
      expect(await driver.get('list'), isNull);
    });

    test('prune does not break a pull of an old file', () async {
      for (int i = 0; i < 20; i++) {
        await driver.put('k$i', i, null);
        // a rename keeps this time, so the moved file looks old
        await driver.fileFor('k$i').setLastModified(_hoursAgo(2));
      }
      List<Future<Object?>> pulls = <Future<Object?>>[
        for (int i = 0; i < 20; i++) driver.pull('k$i'),
      ];
      await driver.prune();
      expect(await Future.wait(pulls), <int>[for (int i = 0; i < 20; i++) i]);
    });

    test('prune does not break the release of an old lock', () async {
      List<CacheLock> locks = <CacheLock>[];
      for (int i = 0; i < 20; i++) {
        CacheLock lock = driver.lock('l$i', const Duration(minutes: 1));
        expect(await lock.get(), isTrue);
        locks.add(lock);
      }
      for (File file in driver.storeDirectory.listSync().whereType<File>()) {
        await file.setLastModified(_hoursAgo(2));
      }
      List<Future<bool>> releases = <Future<bool>>[
        for (CacheLock lock in locks) lock.release(),
      ];
      await driver.prune();
      expect(await Future.wait(releases), everyElement(isTrue));
    });

    test('prune deletes a moved file by the time in its name', () async {
      await driver.storeDirectory.create(recursive: true);
      String hash = _nameOf(driver.fileFor('a'));
      int now = DateTime.now().millisecondsSinceEpoch;
      int old = _hoursAgo(2).millisecondsSinceEpoch;
      String owner = CacheLock.randomOwner();
      File recent = _inStore(driver, '$hash.$now.$owner.mv');
      File oldValue = _inStore(driver, '$hash.$old.$owner.mv');
      File oldLock = _inStore(driver, '$hash.lock.$old.$owner.mv');
      for (File file in <File>[recent, oldValue, oldLock]) {
        await file.writeAsString('{"value":1,"expires_at":null}');
        // a rename keeps the old modified time
        await file.setLastModified(_hoursAgo(2));
      }
      await driver.prune();
      expect(recent.existsSync(), isTrue);
      expect(oldValue.existsSync(), isFalse);
      expect(oldLock.existsSync(), isFalse);
    });

    test('flush deletes values that pull moved away', () async {
      await driver.put('keep-lock-check', 1, null);
      String hash = _nameOf(driver.fileFor('a'));
      int now = DateTime.now().millisecondsSinceEpoch;
      String owner = CacheLock.randomOwner();
      File movedValue = _inStore(driver, '$hash.$now.$owner.mv');
      File movedLock = _inStore(driver, '$hash.klock.$now.$owner.mv');
      await movedValue.writeAsString('{"value":1,"expires_at":null}');
      await movedLock.writeAsString('{}');
      await driver.flush();
      expect(movedValue.existsSync(), isFalse);
      // a lock that is being taken away right now is kept
      expect(movedLock.existsSync(), isTrue);
    });

    test('prune deletes old moved lock files of older versions', () async {
      await driver.storeDirectory.create(recursive: true);
      String hash = _nameOf(driver.fileFor('a'));
      String owner = CacheLock.randomOwner();
      File oldLock = _inStore(driver, '$hash.lock.$owner.tmp');
      File oldKeyLock = _inStore(driver, '$hash.klock.$owner.tmp');
      for (File file in <File>[oldLock, oldKeyLock]) {
        await file.writeAsString('{}');
        await file.setLastModified(_hoursAgo(2));
      }
      // not a name the cache makes: kept
      File foreign = _inStore(driver, '${hash}x.klock.$owner.tmp');
      await foreign.writeAsString('{}');
      await foreign.setLastModified(_hoursAgo(2));
      await driver.prune();
      expect(oldLock.existsSync(), isFalse);
      expect(oldKeyLock.existsSync(), isFalse);
      expect(foreign.existsSync(), isTrue);
    });

    test('a recent moved lock file of an older version is kept', () async {
      await driver.storeDirectory.create(recursive: true);
      String hash = _nameOf(driver.fileFor('a'));
      File recent = _inStore(
        driver,
        '$hash.klock.${CacheLock.randomOwner()}.tmp',
      );
      await recent.writeAsString('{}');
      await driver.prune();
      expect(recent.existsSync(), isTrue);
    });

    test('an expiry time that is not an int is a broken file', () async {
      await driver.storeDirectory.create(recursive: true);
      await driver
          .fileFor('odd')
          .writeAsString('{"value":1,"expires_at":"soon"}');
      expect(await driver.get('odd'), isNull);
      expect(await driver.has('odd'), isFalse);
      expect(await driver.prune(), 1);
    });

    test('a light prune runs by itself, once per hour for all', () async {
      FileDriver other = FileDriver(
        directory: directory,
        prefix: 'p:',
        clock: clock,
      );
      await other.put('c', 1, null);
      await driver.put('old', 1, const Duration(seconds: 1));
      await driver.fileFor('broken').writeAsString('{not json');
      clock.advance(const Duration(seconds: 30));
      await driver.put('a', 2, null);
      // too soon: no prune starts
      expect(driver.backgroundPrune, isNull);

      // the first write a minute or more after the first write
      clock.advance(const Duration(seconds: 31));
      await driver.put('b', 3, null);
      expect(await driver.backgroundPrune, 1);
      expect(driver.fileFor('old').existsSync(), isFalse);
      // a file it can not read may be of another app: it stays
      expect(driver.fileFor('broken').existsSync(), isTrue);
      expect(await driver.get('a'), 2);

      // the lock of that run stops a second driver on the same folder
      // in the same hour
      await driver.put('late', 1, const Duration(seconds: 1));
      clock.advance(const Duration(seconds: 2));
      await other.put('d', 1, null);
      // it starts, but the lock on disk stops it: nothing deleted
      expect(await other.backgroundPrune, 0);
      expect(other.fileFor('late').existsSync(), isTrue);

      // after the hour, a new process (an app restart) prunes again
      clock.advance(const Duration(minutes: 61));
      FileDriver restarted = FileDriver(
        directory: directory,
        prefix: 'p:',
        clock: clock,
      );
      await restarted.put('e', 1, null);
      clock.advance(const Duration(seconds: 61));
      await restarted.put('f', 1, null);
      expect(await restarted.backgroundPrune, 1);
      expect(restarted.fileFor('late').existsSync(), isFalse);
    });

    test('prune skips a key that add or increment holds', () async {
      await driver.put('old', 1, const Duration(seconds: 1));
      clock.advance(const Duration(seconds: 2));
      FileLock held = FileLock(
        File(
          '${driver.fileFor('old').path}${CacheConstants.fileKeyLockSuffix}',
        ),
        clock,
        'old',
        const Duration(seconds: 5),
      );
      expect(await held.get(), isTrue);
      expect(await driver.prune(), 0);
      expect(driver.fileFor('old').existsSync(), isTrue);
      await held.release();
      expect(await driver.prune(), 1);
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

/// the file name of [file], with no folder
String _nameOf(File file) {
  return file.uri.pathSegments.last;
}

/// [name] in the folder of [driver]
File _inStore(FileDriver driver, String name) {
  return File('${driver.storeDirectory.path}${Platform.pathSeparator}$name');
}

DateTime _hoursAgo(int hours) {
  return DateTime.now().subtract(Duration(hours: hours));
}

bool _isLock(String name) {
  return name.endsWith('.lock');
}

bool _isTemp(String name) {
  return name.endsWith('.tmp');
}

bool _isTrue(bool value) {
  return value;
}

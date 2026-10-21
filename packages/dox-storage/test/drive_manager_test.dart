import 'package:dox_storage/dox_storage.dart';
import 'package:test/test.dart';

void main() {
  group('DriveManager', () {
    late MemoryDriver local;
    late MemoryDriver s3;
    late DriveManager drive;

    setUp(() {
      local = MemoryDriver();
      s3 = MemoryDriver();
      drive = DriveManager(
        defaultDisk: 'local',
        disks: <String, DriverContract>{'local': local, 's3': s3},
      );
    });

    test('use() returns the default disk', () async {
      await drive.use().put('a.txt', 'a');
      expect(local.keys, <String>['a.txt']);
      expect(s3.keys, isEmpty);
    });

    test('use(name) returns the named disk', () async {
      await drive.use('s3').put('b.txt', 'b');
      expect(s3.keys, <String>['b.txt']);
    });

    test('unknown disk throws', () {
      expect(
        () => drive.use('ftp'),
        throwsA(isA<UnsupportedOperationException>()),
      );
    });

    test('register adds a custom driver', () async {
      MemoryDriver custom = MemoryDriver();
      drive.register('custom', custom);
      await drive.use('custom').put('c.txt', 'c');
      expect(custom.keys, <String>['c.txt']);
      expect(drive.diskNames, containsAll(<String>['local', 's3', 'custom']));
    });

    test('fake swaps a disk until restore', () async {
      Disk fake = drive.fake('s3');
      await drive.use('s3').put('f.txt', 'f');
      expect(await fake.exists('f.txt'), isTrue);
      expect(s3.keys, isEmpty);

      drive.restore('s3');
      expect(await drive.use('s3').exists('f.txt'), isFalse);
    });

    test('fake without a name fakes the default disk', () async {
      drive.fake();
      await drive.use().put('x.txt', 'x');
      expect(local.keys, isEmpty);
      drive.restoreAll();
      expect(await drive.use().exists('x.txt'), isFalse);
    });
  });

  group('Disk error wrapping', () {
    test('unknown driver errors become DriverException with the key', () async {
      Disk disk = Disk(_BrokenDriver());
      expect(
        disk.get('a.txt'),
        throwsA(
          isA<DriverException>()
              .having((DriverException e) => e.key, 'key', 'a.txt')
              .having(
                  (DriverException e) => e.cause, 'cause', isA<StateError>()),
        ),
      );
    });
  });
}

class _BrokenDriver extends MemoryDriver {
  @override
  Future<Never> get(String key) async {
    throw StateError('disk on fire');
  }
}

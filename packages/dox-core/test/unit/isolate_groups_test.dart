import 'dart:io';

import 'package:dox_core/isolate/group_identity.dart';
import 'package:dox_core/isolate/snapshot_locator.dart';
import 'package:test/test.dart';

void main() {
  group('GroupIdentity |', () {
    test('the name makes the same identity again', () {
      GroupIdentity id = const GroupIdentity(3, 8, 123456789);
      expect(id.debugName, 'dox-group-3-8-123456789');
      GroupIdentity? back = GroupIdentity.parse(id.debugName);
      expect(back?.isolateId, 3);
      expect(back?.isolateCount, 8);
      expect(back?.primaryPort, 123456789);
    });

    test('a port id below zero is read', () {
      GroupIdentity id = const GroupIdentity(2, 4, -987654321);
      expect(id.debugName, 'dox-group-2-4--987654321');
      expect(GroupIdentity.parse(id.debugName)?.primaryPort, -987654321);
    });

    test('other names are not a group', () {
      expect(GroupIdentity.parse(null), isNull);
      expect(GroupIdentity.parse('main'), isNull);
      expect(GroupIdentity.parse('dox-group-'), isNull);
      expect(GroupIdentity.parse('dox-group-2-3'), isNull);
      expect(GroupIdentity.parse('dox-group-a-3-4'), isNull);
      expect(GroupIdentity.parse('dox-group-2-3-4-5'), isNull);
      // the primary is id 1, and the id is never above the count
      expect(GroupIdentity.parse('dox-group-1-3-4'), isNull);
      expect(GroupIdentity.parse('dox-group-5-3-4'), isNull);
    });

    test('the isolate of the test is not a group', () {
      expect(GroupIdentity.current, isNull);
    });
  });

  group('SnapshotLocator |', () {
    late Directory dir;
    late String exe;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dox_snapshot_');
      Directory('${dir.path}/bin').createSync();
      Directory('${dir.path}/lib').createSync();
      exe = '${dir.path}/bin/app';
      File(exe).writeAsStringSync('exe');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    Uri script(String name) => Uri.file('${dir.path}/$name');

    test('the Linux bundle library comes first', () {
      File('${dir.path}/lib/libdartaotapp.so').writeAsStringSync('so');
      File('$exe.aot').writeAsStringSync('aot');
      File('${dir.path}/main.dart').writeAsStringSync('');
      SnapshotLocator locator = SnapshotLocator(
        executable: exe,
        script: script('main.dart'),
        isLinux: true,
      );
      expect(locator.find()?.toFilePath(), '${dir.path}/lib/libdartaotapp.so');
    });

    test('the bundle library is only for Linux', () {
      File('${dir.path}/lib/libdartaotapp.so').writeAsStringSync('so');
      File('$exe.aot').writeAsStringSync('aot');
      SnapshotLocator locator = SnapshotLocator(
        executable: exe,
        script: script('none.dart'),
        isLinux: false,
      );
      expect(locator.find()?.toFilePath(), '$exe.aot');
    });

    test('then the aot file, then the script', () {
      File('${dir.path}/main.dart').writeAsStringSync('');
      SnapshotLocator locator = SnapshotLocator(
        executable: exe,
        script: script('main.dart'),
        isLinux: true,
      );
      expect(locator.find()?.toFilePath(), '${dir.path}/main.dart');
    });

    test('a file that is missing is skipped', () {
      SnapshotLocator locator = SnapshotLocator(
        executable: exe,
        script: script('missing.dart'),
        isLinux: true,
      );
      expect(locator.find(), isNull);
    });

    test('the executable is never given', () {
      // a compiled exe: the script is the executable itself
      SnapshotLocator locator = SnapshotLocator(
        executable: exe,
        script: Uri.file(exe),
        isLinux: true,
      );
      expect(locator.find(), isNull);
    });

    test('a link to the executable is never given', () {
      // the script is the executable under another name
      Link('${dir.path}/app.dart').createSync(exe);
      Link('$exe.aot').createSync(exe);
      SnapshotLocator locator = SnapshotLocator(
        executable: exe,
        script: script('app.dart'),
        isLinux: false,
      );
      expect(locator.find(), isNull);
    });

    test('a script of an unknown kind is skipped', () {
      File('${dir.path}/server').writeAsStringSync('exe');
      SnapshotLocator locator = SnapshotLocator(
        executable: exe,
        script: script('server'),
        isLinux: false,
      );
      expect(locator.find(), isNull);
    });

    test('a script that is not a file is skipped', () {
      SnapshotLocator locator = SnapshotLocator(
        executable: exe,
        script: Uri.parse('data:application/dart;charset=utf-8,void main(){}'),
        isLinux: true,
      );
      expect(locator.find(), isNull);
    });
  });
}

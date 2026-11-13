import 'dart:io';

import 'package:dox_annotation/command.dart';
import 'package:test/test.dart';

void main() {
  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('dox_migration_file_');
  });

  tearDown(() {
    folder.deleteSync(recursive: true);
  });

  test('writes a file with the make:migration name format', () {
    String? path = MigrationFile(folder: folder)
        .create('create_queue_tables', '// up');
    expect(path, isNotNull);
    String name = File(path!).uri.pathSegments.last;
    expect(
      RegExp(r'^\d{4}_\d{2}_\d{2}_\d{6}_create_queue_tables\.dart$')
          .hasMatch(name),
      isTrue,
      reason: name,
    );
    expect(File(path).readAsStringSync(), '// up');
  });

  test('sorts after a newer file in the folder', () {
    File('${folder.path}/2999_01_01_000000_later.dart').writeAsStringSync('');
    String path = MigrationFile(folder: folder).create('x', '')!;
    expect(path, endsWith('2999_01_01_000001_x.dart'));
  });

  test('sees a migration with a 9-digit time, like the app template', () {
    File('${folder.path}/2026_10_25_000000000_create_queue_tables.dart')
        .writeAsStringSync('old');
    MigrationFile file = MigrationFile(folder: folder);
    expect(file.exists('create_queue_tables'), isTrue);
    expect(file.create('create_queue_tables', 'new'), isNull);
    expect(file.exists('queue_tables'), isFalse);
    expect(folder.listSync(), hasLength(1));
  });

  test('does not write a second migration with the same name', () {
    File('${folder.path}/2020_01_01_000000_create_queue_tables.dart')
        .writeAsStringSync('old');
    MigrationFile file = MigrationFile(folder: folder);
    expect(file.exists('create_queue_tables'), isTrue);
    expect(file.create('create_queue_tables', 'new'), isNull);
    expect(folder.listSync(), hasLength(1));
  });
}

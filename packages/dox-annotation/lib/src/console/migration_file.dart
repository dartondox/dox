import 'dart:io';

/// Write a Dart migration into `db/migration`, with the same file name
/// as `dox make:migration`: `2026_10_21_120000_create_queue_tables.dart`.
///
/// Use it in a package command that adds a migration, like `queue:table`.
/// `dox migrate` then writes `db/migration/migrations.dart` again (and
/// makes `bin/migrate.dart` when it is missing), so the new file runs.
///
/// Keep the name rules the same as `createMigration` and
/// `nextMigrationTime` in dox-cli (`lib/src/tools/create_migration.dart`).
/// dox-cli does not use this class yet, so the rules are in both places.
class MigrationFile {
  /// [folder] is `db/migration` of the current folder by default.
  MigrationFile({Directory? folder})
    : folder = folder ?? Directory('${Directory.current.path}/db/migration');

  final Directory folder;

  static final RegExp _stamp = RegExp(
    r'^(\d{4})_(\d{2})_(\d{2})_(\d{2})(\d{2})(\d{2})_',
  );

  /// any migration file name, with any number of digits for the time,
  /// like the `2026_10_25_000000000_` files of the app template. Same
  /// rule as the migration list of the `dox` CLI.
  static final RegExp _name = RegExp(
    r'^\d{4}_\d{2}_\d{2}_\d+_(\w+)\.(dart|sql)$',
  );

  /// write [source] as a new migration named [name] (snake case, like
  /// `create_queue_tables`) and return its path.
  /// Return null and write nothing when a migration with this name is
  /// already in the folder, so a second run does not add the tables twice.
  String? create(String name, String source) {
    if (exists(name)) return null;
    File file = File('${folder.path}/${_timestamp(_nextTime())}_$name.dart');
    file.createSync(recursive: true);
    file.writeAsStringSync(source);
    return file.path;
  }

  /// true when a migration named [name] is in the folder, at any time
  bool exists(String name) {
    for (File file in _files()) {
      RegExpMatch? match = _name.firstMatch(file.uri.pathSegments.last);
      if (match != null && match.group(1) == name) return true;
    }
    return false;
  }

  /// now, or 1 second after the newest migration, so the new file sorts
  /// last (migrations run sorted by file name). Same rule as
  /// `dox make:migration`.
  DateTime _nextTime() {
    DateTime now = DateTime.now();
    DateTime time = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    for (File file in _files()) {
      RegExpMatch? m = _stamp.firstMatch(file.uri.pathSegments.last);
      if (m == null) continue;
      DateTime last = DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      );
      if (!time.isAfter(last)) time = last.add(const Duration(seconds: 1));
    }
    return time;
  }

  List<File> _files() {
    if (!folder.existsSync()) return <File>[];
    return folder.listSync().whereType<File>().toList();
  }

  /// `2026_10_21_120000`
  String _timestamp(DateTime t) {
    return '${t.year}_${_two(t.month)}_${_two(t.day)}_'
        '${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}

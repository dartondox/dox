import 'dart:io';

import 'package:dox_migration/src/utils/file_extension.dart';
import 'package:dox_migration/src/utils/logger.dart';
import 'package:dox_migration/src/utils/utils.dart';
import 'package:postgres_pool/postgres_pool.dart';

class SqlExtMigration {
  final PgPool pool;
  final MigrationType type;

  const SqlExtMigration({
    required this.pool,
    required this.type,
  });

  Future<void> run(File file, int batch) async {
    String info = type == MigrationType.up ? 'Migrating' : 'Rolling back';
    Logger.info('$info: ${file.name}');
    Map<String, String> queries = getQueries(file);
    try {
      if (type == MigrationType.up) {
        await _runQuery(queries['up'], file, batch);
      }
      if (type == MigrationType.down) {
        await _runQuery(queries['down'], file, batch);
      }

      String info2 = type == MigrationType.up ? 'Migrated' : 'Finished';
      Logger.info('$info2: ${file.name}');
    } catch (error) {
      Logger.warn(queries[MigrationType.up.name]);
      Logger.danger('Error: ${error.toString()}');
    }
  }

  Map<String, String> getQueries(File file) {
    String contents = fileGetContents(file);
    RegExp regex = RegExp(r'-- (up|down)\n([^--]+)', multiLine: true);
    Iterable<RegExpMatch> matches = regex.allMatches(contents);

    Map<String, String> resultMap = <String, String>{};

    for (RegExpMatch match in matches) {
      String? key = match.group(1);
      String? value = match.group(2);
      if (key != null) {
        resultMap[key.toLowerCase()] =
            (value ?? '').trim().replaceAll('\n', ' ');
      }
    }

    return resultMap;
  }

  Future<void> _runQuery(String? query, File file, int batch) async {
    if (query == null) return;
    if (query.isEmpty) return;
    query = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    await pool.query(query);
    await saveMigratedRecord(pool, file, batch, type);
  }
}

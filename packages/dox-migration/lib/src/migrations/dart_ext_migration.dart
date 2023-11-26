import 'dart:io';

import 'package:dox_migration/src/utils/file_extension.dart';
import 'package:dox_migration/src/utils/logger.dart';
import 'package:dox_migration/src/utils/utils.dart';
import 'package:postgres_pool/postgres_pool.dart';

class DartExtMigration {
  final Directory tempDirectory;
  final Directory migrationDirectory;
  final PgEndpoint databaseEndPoint;
  final PgPool pool;
  final MigrationType type;

  const DartExtMigration({
    required this.tempDirectory,
    required this.migrationDirectory,
    required this.databaseEndPoint,
    required this.pool,
    required this.type,
  });

  Future<void> run(File file, int batch) async {
    String info = type == MigrationType.up ? 'Migrating' : 'Rolling back';
    Logger.info('$info: ${file.name}');

    ProcessResult result =
        Process.runSync('dart', <String>[_createTempFileToRun(file).path]);

    if (result.stderr != '') {
      Logger.danger('Error: ${result.stderr}');
    } else {
      await saveMigratedRecord(pool, file, batch, type);
      String info2 = type == MigrationType.up ? 'Migrated' : 'Finished';
      Logger.info('$info2: ${file.name}');
    }
  }

  File _createTempFileToRun(File file) {
    String content = fileGetContents(file);
    String newContent = """
    import 'package:postgres_pool/postgres_pool.dart';
    $content

    void main() async {
      PgPool pool = PgPool(
        PgEndpoint(
          host: '${databaseEndPoint.host}',
          port: ${databaseEndPoint.port},
          database: '${databaseEndPoint.database}',
          username: '${databaseEndPoint.username}',
          password: '${databaseEndPoint.password}',
        ),
        settings: PgPoolSettings()
          ..maxConnectionAge = Duration(minutes: 60)
          ..concurrency = 4,
      );
      SqlQueryBuilder.initialize(database: pool);
      try {
        await ${type.name}();
        pool.close();
      } catch(error) {
        pool.close();
      }
    }
    """;

    File tempFile = _createNewTempFile(file);
    tempFile.createSync(recursive: true);
    tempFile.writeAsStringSync(newContent);
    return tempFile;
  }

  File _createNewTempFile(File file) {
    String filename = file.name;
    String timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    return File('${tempDirectory.path}/$timestamp$filename.temp');
  }
}

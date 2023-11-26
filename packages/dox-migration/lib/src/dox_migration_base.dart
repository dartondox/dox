import 'dart:io';

import 'package:dox_migration/src/migrations/dart_ext_migration.dart';
import 'package:dox_migration/src/migrations/sql_ext_migration.dart';
import 'package:dox_migration/src/utils/env.dart';
import 'package:dox_migration/src/utils/file_extension.dart';
import 'package:dox_migration/src/utils/logger.dart';
import 'package:dox_migration/src/utils/utils.dart';
import 'package:postgres_pool/postgres_pool.dart';

class Migration {
  late PgPool pool;
  String from;

  Migration({this.from = 'app'});

  /// main function to run migration
  /// - will create migration table if not exist
  /// - will run migrations from db/migration folder
  Future<void> migrate({PgEndpoint? endPoint}) async {
    endPoint = getEndpoint(endPoint);
    pool = PgPool(endPoint);
    await createMigrationTableIfNotExist(pool);
    await _runMigration(endPoint, MigrationType.up);
    await _closeConnection();
  }

  /// main function to run migration
  /// - will create migration table if not exist
  /// - will run migrations from db/migration folder
  Future<void> rollback({PgEndpoint? endPoint}) async {
    endPoint = getEndpoint(endPoint);
    pool = PgPool(endPoint);
    await createMigrationTableIfNotExist(pool);
    await _runMigration(endPoint, MigrationType.down);
    await _closeConnection();
  }

  PgEndpoint getEndpoint(PgEndpoint? endPoint) {
    if (endPoint != null) {
      return endPoint;
    }
    // get endpoint from env
    Map<String, String> env = loadEnv();
    return PgEndpoint(
      host: env['DB_HOST'] ?? 'localhost',
      port: int.parse(env['DB_PORT'] ?? '5432'),
      database: env['DB_NAME'] ?? 'dox',
      username: env['DB_USERNAME'] ?? 'postgres',
      password: env['DB_PASSWORD'] ?? 'postgres',
    );
  }

  /// clear temporary directory
  Future<void> _clearTempFolder() async {
    Directory tempFolder = getTempDirectory();
    if (tempFolder.existsSync()) {
      await tempFolder.delete(recursive: true);
    }
  }

  /// check whether migration is already done or not
  Future<bool> isMigrated(File file) async {
    String query = '''
      SELECT * FROM dox_db_migration 
      WHERE migration = @filename 
      LIMIT 1 OFFSET 0
    ''';

    List<Map<String, Map<String, dynamic>>> migratedValue =
        await pool.mappedResultsQuery(
      query,
      substitutionValues: <String, String>{'filename': file.name},
    );
    return migratedValue.isNotEmpty;
  }

  /// process migration
  Future<void> _runMigration(
      PgEndpoint databaseEndPoint, MigrationType type) async {
    try {
      Directory migrationDirectory = getMigrationDirectory();
      Directory tempDirectory = getTempDirectory();

      List<File> migrationFiles = getFilesFromDirectory(migrationDirectory);
      int nextBatch = await getNextBatchNumber(pool);

      List<File> newMigrationFileList = <File>[];

      for (File file in migrationFiles) {
        bool showRunMigration = true;

        if (type == MigrationType.up) {
          showRunMigration = await isMigrated(file) == false;
        } else {
          showRunMigration = await isMigrated(file) == true;
        }

        if (showRunMigration) {
          newMigrationFileList.add(file);
          if (file.ext == 'dart') {
            await DartExtMigration(
              pool: pool,
              tempDirectory: tempDirectory,
              databaseEndPoint: databaseEndPoint,
              migrationDirectory: migrationDirectory,
              type: type,
            ).run(file, nextBatch);
          }

          if (file.ext == 'sql') {
            await SqlExtMigration(pool: pool, type: type).run(file, nextBatch);
          }
        }
      }

      await _clearTempFolder();

      if (newMigrationFileList.isEmpty && type == MigrationType.up) {
        Logger.info('Migrations are already up to date!');
      }

      if (newMigrationFileList.isEmpty && type == MigrationType.down) {
        Logger.info('Nothing to rollback!');
      }
    } catch (error) {
      print(error);
    }
  }

  Future<void> _closeConnection() async {
    await pool.close();
  }
}

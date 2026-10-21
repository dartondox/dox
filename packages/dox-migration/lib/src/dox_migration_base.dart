import 'dart:io';

import 'package:dox_migration/src/migrations/sql_ext_migration.dart';
import 'package:dox_migration/src/utils/db_connection.dart';
import 'package:dox_migration/src/utils/env.dart';
import 'package:dox_migration/src/utils/file_extension.dart';
import 'package:dox_migration/src/utils/logger.dart';
import 'package:dox_migration/src/utils/utils.dart';

class Migration {
  String from;

  Migration({this.from = 'app'});

  /// main function to run migration
  /// - will create migration table if not exist
  /// - will run migrations from db/migration folder
  /// - [connection] is optional postgres `Connection` or mysql `MySqlConnection`
  Future<void> migrate([dynamic connection]) async {
    DbConnection conn = await _getConnection(connection);
    await createMigrationTableIfNotExist(conn);
    await _runMigration(conn, MigrationType.up);
    await _closeConnection(conn);
  }

  /// main function to run migration
  /// - will create migration table if not exist
  /// - will run migrations from db/migration folder
  /// - [connection] is optional postgres `Connection` or mysql `MySqlConnection`
  Future<void> rollback([dynamic connection]) async {
    DbConnection conn = await _getConnection(connection);
    await createMigrationTableIfNotExist(conn);
    await _runMigration(conn, MigrationType.down);
    await _closeConnection(conn);
  }

  Future<DbConnection> _getConnection(dynamic connection) async {
    if (connection != null) return DbConnection(connection);
    // get endpoint from env
    Map<String, String> env = loadEnv();
    try {
      return await DbConnection.open(env);
    } catch (e) {
      throw Exception('Could not connect to database: $e');
    }
  }

  /// clear temporary directory
  Future<void> _clearTempFolder() async {
    Directory tempFolder = getTempDirectory();
    if (tempFolder.existsSync()) {
      await tempFolder.delete(recursive: true);
    }
  }

  /// check whether migration is already done or not
  Future<bool> isMigrated(DbConnection conn, File file) async {
    String query = '''
      SELECT * FROM dox_db_migration 
      WHERE migration = ? 
      LIMIT 1 OFFSET 0
    ''';

    List<Map<String, dynamic>> migratedValue =
        await conn.execute(query, <Object>[file.name]);
    return migratedValue.isNotEmpty;
  }

  /// process migration
  Future<void> _runMigration(DbConnection conn, MigrationType type) async {
    try {
      Directory migrationDirectory = getMigrationDirectory();

      List<File> migrationFiles = getFilesFromDirectory(migrationDirectory);
      int nextBatch = await getNextBatchNumber(conn);

      List<File> newMigrationFileList = <File>[];

      for (File file in migrationFiles) {
        bool showRunMigration = true;

        if (type == MigrationType.up) {
          showRunMigration = await isMigrated(conn, file) == false;
        } else {
          showRunMigration = await isMigrated(conn, file) == true;
        }

        if (showRunMigration) {
          newMigrationFileList.add(file);
          if (file.ext == 'sql') {
            await SqlExtMigration(conn: conn, type: type).run(file, nextBatch);
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

  Future<void> _closeConnection(DbConnection conn) async {
    await conn.close();
  }
}

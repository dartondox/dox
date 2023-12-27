import 'dart:io';

import 'package:dox_migration/src/migrations/sql_ext_migration.dart';
import 'package:dox_migration/src/utils/env.dart';
import 'package:dox_migration/src/utils/file_extension.dart';
import 'package:dox_migration/src/utils/logger.dart';
import 'package:dox_migration/src/utils/utils.dart';
import 'package:postgres/postgres.dart';

class Migration {
  String from;

  Migration({this.from = 'app'});

  /// main function to run migration
  /// - will create migration table if not exist
  /// - will run migrations from db/migration folder
  Future<void> migrate([Connection? connection]) async {
    Connection conn = connection ?? await _getConnection();
    await createMigrationTableIfNotExist(conn);
    await _runMigration(conn, MigrationType.up);
    await _closeConnection(conn);
  }

  /// main function to run migration
  /// - will create migration table if not exist
  /// - will run migrations from db/migration folder
  Future<void> rollback([Connection? connection]) async {
    Connection conn = connection ?? await _getConnection();
    await createMigrationTableIfNotExist(conn);
    await _runMigration(conn, MigrationType.down);
    await _closeConnection(conn);
  }

  Future<Connection> _getConnection() async {
    // get endpoint from env
    Map<String, String> env = loadEnv();
    return await Connection.open(
      Endpoint(
        host: env['DB_HOST'] ?? 'localhost',
        port: int.parse(env['DB_PORT'] ?? '5432'),
        database: env['DB_NAME'] ?? 'dox',
        username: env['DB_USERNAME'] ?? 'postgres',
        password: env['DB_PASSWORD'] ?? 'postgres',
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
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
  Future<bool> isMigrated(Connection conn, File file) async {
    String query = '''
      SELECT * FROM dox_db_migration 
      WHERE migration = @filename 
      LIMIT 1 OFFSET 0
    ''';

    Result migratedValue = await conn.execute(Sql.named(query),
        parameters: <String, String>{'filename': file.name});
    return migratedValue.isNotEmpty;
  }

  /// process migration
  Future<void> _runMigration(Connection conn, MigrationType type) async {
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

  Future<void> _closeConnection(Connection conn) async {
    await conn.close();
  }
}

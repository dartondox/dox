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
  /// - [connection] is optional postgres `Connection`/`Pool`, mysql `MySQLConnection`/`MySQLConnectionPool` or sqlite `Database`
  Future<void> migrate([dynamic connection]) async {
    DbConnection conn = await _getConnection(connection);
    try {
      await createMigrationTableIfNotExist(conn);
      await _runMigration(conn);
    } finally {
      await _closeConnection(conn);
    }
  }

  /// undo migrations, newest first
  /// - without [step], undo the last batch
  /// - with [step], undo the last [step] migrations
  /// - [connection] is optional postgres `Connection`/`Pool`, mysql `MySQLConnection`/`MySQLConnectionPool` or sqlite `Database`
  Future<void> rollback([dynamic connection, int? step]) async {
    DbConnection conn = await _getConnection(connection);
    try {
      await createMigrationTableIfNotExist(conn);
      await _runRollback(conn, step: step);
    } finally {
      await _closeConnection(conn);
    }
  }

  /// undo all migrations, newest first
  Future<void> reset([dynamic connection]) async {
    DbConnection conn = await _getConnection(connection);
    try {
      await createMigrationTableIfNotExist(conn);
      await _runRollback(conn, all: true);
    } finally {
      await _closeConnection(conn);
    }
  }

  /// undo all migrations, then run them again
  Future<void> refresh([dynamic connection]) async {
    DbConnection conn = await _getConnection(connection);
    try {
      await createMigrationTableIfNotExist(conn);
      await _runRollback(conn, all: true);
      await _runMigration(conn);
    } finally {
      await _closeConnection(conn);
    }
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

    List<Map<String, dynamic>> migratedValue = await conn.execute(
      query,
      <Object>[file.name],
    );
    return migratedValue.isNotEmpty;
  }

  /// run migrations that are not done yet, in file order.
  /// throw on the first failed migration, later ones may need it.
  Future<void> _runMigration(DbConnection conn) async {
    try {
      Directory migrationDirectory = getMigrationDirectory();

      List<File> migrationFiles = getFilesFromDirectory(migrationDirectory);
      int nextBatch = await getNextBatchNumber(conn);

      List<File> newMigrationFileList = <File>[];

      for (File file in migrationFiles) {
        if (await isMigrated(conn, file)) continue;
        newMigrationFileList.add(file);
        if (!await _runFile(conn, file, MigrationType.up, nextBatch)) {
          throw Exception('Migration failed: ${file.name}');
        }
      }

      if (newMigrationFileList.isEmpty) {
        Logger.info('Migrations are already up to date!');
      }
    } finally {
      await _clearTempFolder();
    }
  }

  /// undo migrations from dox_db_migration table, newest first.
  /// throw on the first failed or missing migration.
  Future<void> _runRollback(
    DbConnection conn, {
    int? step,
    bool all = false,
  }) async {
    try {
      String query = 'SELECT migration FROM dox_db_migration';
      if (step != null && !all) {
        query += ' ORDER BY id DESC LIMIT $step';
      } else if (!all) {
        query += ' WHERE batch = (SELECT MAX(batch) FROM dox_db_migration)'
            ' ORDER BY id DESC';
      } else {
        query += ' ORDER BY id DESC';
      }
      List<Map<String, dynamic>> rows = await conn.execute(query);

      Map<String, File> files = <String, File>{
        for (File file in getFilesFromDirectory(getMigrationDirectory()))
          file.name: file,
      };

      for (Map<String, dynamic> row in rows) {
        File? file = files[row['migration'].toString()];
        if (file == null) {
          throw Exception('Migration file not found: ${row['migration']}');
        }
        if (!await _runFile(conn, file, MigrationType.down, 0)) {
          throw Exception('Rollback failed: ${file.name}');
        }
      }

      if (rows.isEmpty) {
        Logger.info('Nothing to rollback!');
      }
    } finally {
      await _clearTempFolder();
    }
  }

  /// run one migration file, return false when it failed
  Future<bool> _runFile(
    DbConnection conn,
    File file,
    MigrationType type,
    int batch,
  ) async {
    if (file.ext != 'sql') return true;
    return SqlExtMigration(conn: conn, type: type).run(file, batch);
  }

  Future<void> _closeConnection(DbConnection conn) async {
    await conn.close();
  }
}

import 'dart:io';

import 'package:dox_migration/src/utils/file_extension.dart';
import 'package:postgres_pool/postgres_pool.dart';

enum MigrationType { up, down }

/// get content from file
String fileGetContents(File file) {
  return File(file.path).readAsStringSync();
}

/// crete migration table if not exist
Future<void> createMigrationTableIfNotExist(PgPool pool) async {
  String query = '''
      CREATE TABLE IF NOT EXISTS dox_db_migration 
      (
        id SERIAL PRIMARY KEY NOT NULL, 
        migration VARCHAR(100) NOT NULL,
        batch INTEGER NOT NULL
      )
    ''';
  await pool.query(query);
}

/// save migration record to migrations table with batch number
Future<void> saveMigratedRecord(
    PgPool pool, File file, int batch, MigrationType type) async {
  if (type == MigrationType.up) {
    String query = '''
      INSERT INTO dox_db_migration 
      (migration,batch) 
      VALUES 
      (@filename, @batch) 
      RETURNING id
    ''';
    await pool.query(query, substitutionValues: <String, dynamic>{
      'filename': file.name,
      'batch': batch
    });
    return;
  }

  String query = '''
      DELETE from dox_db_migration 
      WHERE migration = @filename
    ''';
  await pool.query(query, substitutionValues: <String, dynamic>{
    'filename': file.name,
  });
  return;
}

// get the next batch number
Future<int> getNextBatchNumber(PgPool pool) async {
  String query = '''
        SELECT batch FROM dox_db_migration 
        ORDER BY batch desc 
        LIMIT 1 OFFSET 0
      ''';
  List<Map<String, Map<String, dynamic>>> latestBatch =
      await pool.mappedResultsQuery(query);

  int batchNumber = 1;

  if (latestBatch.isNotEmpty && latestBatch.first.isNotEmpty) {
    if (latestBatch.first['dox_db_migration']?['batch'] != null) {
      String latestBatchNumberString =
          latestBatch.first['dox_db_migration']?['batch'].toString() ?? '0';
      batchNumber = int.parse(latestBatchNumberString) + 1;
    }
  }
  return batchNumber;
}

/// get migration directory `db/migration`
Directory getMigrationDirectory() {
  return Directory('${Directory.current.path}/db/migration');
}

/// get temporary directory `db/migration/tmp`
Directory getTempDirectory() {
  return Directory('${getMigrationDirectory().path}/tmp');
}

/// get list of files from db/migration folder
List<File> getFilesFromDirectory(Directory migrationDirectory) {
  List<File> migrationFiles = migrationDirectory
      .listSync()
      .whereType<File>()
      .where((File entity) =>
          entity.path.endsWith('.dart') || entity.path.endsWith('.sql'))
      .toList();

  /// sort by filename
  migrationFiles.sort((File a, File b) => a.path.compareTo(b.path));
  return migrationFiles;
}

import 'dart:io';

import 'package:dox_migration/src/utils/file_extension.dart';
import 'package:postgres/postgres.dart';

enum MigrationType { up, down }

/// get content from file
String fileGetContents(File file) {
  return File(file.path).readAsStringSync();
}

/// crete migration table if not exist
Future<void> createMigrationTableIfNotExist(Connection conn) async {
  String query = '''
      CREATE TABLE IF NOT EXISTS dox_db_migration 
      (
        id SERIAL PRIMARY KEY NOT NULL, 
        migration VARCHAR(100) NOT NULL,
        batch INTEGER NOT NULL
      )
    ''';
  await conn.execute(Sql.named(query));
}

/// save migration record to migrations table with batch number
Future<void> saveMigratedRecord(
    Connection conn, File file, int batch, MigrationType type) async {
  if (type == MigrationType.up) {
    String query = '''
      INSERT INTO dox_db_migration 
      (migration,batch) 
      VALUES 
      (@filename, @batch) 
      RETURNING id
    ''';
    await conn.execute(Sql.named(query),
        parameters: <String, dynamic>{'filename': file.name, 'batch': batch});
    return;
  }

  String query = '''
      DELETE from dox_db_migration 
      WHERE migration = @filename
    ''';
  await conn.execute(Sql.named(query), parameters: <String, dynamic>{
    'filename': file.name,
  });
  return;
}

// get the next batch number
Future<int> getNextBatchNumber(Connection conn) async {
  String query = '''
        SELECT batch FROM dox_db_migration 
        ORDER BY batch desc 
        LIMIT 1 OFFSET 0
      ''';
  Result latestBatch = await conn.execute(query);

  int batchNumber = 1;

  if (latestBatch.isNotEmpty && latestBatch.first.isNotEmpty) {
    int? latestBatchNumber = latestBatch.first.toColumnMap()['batch'] ?? 0;
    if (latestBatchNumber != null) {
      String latestBatchNumberString = latestBatchNumber.toString();
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

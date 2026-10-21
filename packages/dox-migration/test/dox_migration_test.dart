import 'dart:io';

import 'package:dox_migration/dox_migration.dart';
import 'package:dox_migration/src/utils/db_connection.dart';
import 'package:test/test.dart';

/// env for each driver, defaults match the services in .github/workflows
Map<String, Map<String, String>> drivers = <String, Map<String, String>>{
  'postgres': <String, String>{
    'DB_CONNECTION': 'postgres',
    'DB_HOST': 'localhost',
    'DB_PORT': Platform.environment['PG_PORT'] ?? '5432',
    'DB_NAME': 'postgres',
    'DB_USERNAME': 'postgres',
    'DB_PASSWORD': 'postgres',
  },
  'mysql': <String, String>{
    'DB_CONNECTION': 'mysql',
    'DB_HOST': 'localhost',
    'DB_PORT': Platform.environment['MYSQL_PORT'] ?? '3306',
    'DB_NAME': 'dox-framework',
    'DB_USERNAME': 'dox',
    'DB_PASSWORD': 'password',
  },
};

void main() {
  Directory originalDir = Directory.current;

  for (String driver in drivers.keys) {
    group(driver, () {
      Map<String, String> env = drivers[driver]!;
      late Directory tempDir;
      late DbConnection db;

      void writeMigration(String name, String sql) {
        File('${tempDir.path}/db/migration/$name.sql').writeAsStringSync(sql);
      }

      Future<List<Map<String, dynamic>>> migrations() {
        return db.execute(
            'SELECT migration, batch FROM dox_db_migration ORDER BY id');
      }

      Future<bool> tableExists(String table) async {
        try {
          await db.execute('SELECT * FROM $table');
          return true;
        } catch (_) {
          return false;
        }
      }

      setUp(() async {
        tempDir = Directory.systemTemp.createTempSync('dox_migration_');
        Directory('${tempDir.path}/db/migration').createSync(recursive: true);
        File('${tempDir.path}/.env').writeAsStringSync(env.entries
            .map((MapEntry<String, String> e) => '${e.key}=${e.value}')
            .join('\n'));
        Directory.current = tempDir;

        db = await DbConnection.open(env);
        for (String table in <String>[
          'dox_db_migration',
          'mig_blog',
          'mig_tag',
          'mig_fail',
        ]) {
          await db.execute('DROP TABLE IF EXISTS $table');
        }
      });

      tearDown(() async {
        await db.close();
        Directory.current = originalDir;
        tempDir.deleteSync(recursive: true);
      });

      test('migrate and rollback with batch numbers', () async {
        writeMigration('2023_01_01_000000_create_blog', '''
-- up
CREATE TABLE mig_blog (
  id INTEGER PRIMARY KEY,
  title VARCHAR(255)
);
INSERT INTO mig_blog (id, title) VALUES (1, 'hello')

-- down
DROP TABLE IF EXISTS mig_blog
''');

        await Migration().migrate();
        expect(await tableExists('mig_blog'), true);
        List<Map<String, dynamic>> rows =
            await db.execute('SELECT title FROM mig_blog');
        expect(rows.first['title'], 'hello');
        expect((await migrations()).map((Map<String, dynamic> r) => r['batch']),
            <int>[1]);

        // nothing new, nothing changes
        await Migration().migrate();
        expect((await migrations()).length, 1);

        writeMigration('2023_01_02_000000_create_tag', '''
-- up
CREATE TABLE mig_tag (id INTEGER PRIMARY KEY)

-- down
DROP TABLE IF EXISTS mig_tag
''');
        await Migration().migrate();
        expect(await tableExists('mig_tag'), true);
        expect((await migrations()).map((Map<String, dynamic> r) => r['batch']),
            <int>[1, 2]);

        await Migration().rollback();
        expect(await tableExists('mig_blog'), false);
        expect(await tableExists('mig_tag'), false);
        expect(await migrations(), isEmpty);
      });

      test('failed migration is not recorded', () async {
        writeMigration('2023_01_01_000000_fail', '''
-- up
CREATE TABLE mig_fail (id INTEGER PRIMARY KEY);
INSERT INTO not_a_table VALUES (1)

-- down
DROP TABLE IF EXISTS mig_fail
''');

        await Migration().migrate();
        expect(await migrations(), isEmpty);
        // mysql auto commits DDL, so only postgres rolls back the table
        expect(await tableExists('mig_fail'), driver == 'mysql');
      });
    });
  }
}

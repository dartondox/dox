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
  // no server needed, the file is made in a new temp folder per run, so
  // two test runs at the same time do not share it
  'sqlite': <String, String>{
    'DB_CONNECTION': 'sqlite',
    'DB_DATABASE': '${sqliteDir.path}/dox_migration_test.db',
  },
};

final Directory sqliteDir = Directory.systemTemp.createTempSync(
  'dox_migration_sqlite_',
);

void main() {
  Directory originalDir = Directory.current;

  tearDownAll(() {
    if (sqliteDir.existsSync()) sqliteDir.deleteSync(recursive: true);
  });

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
          'SELECT migration, batch FROM dox_db_migration ORDER BY id',
        );
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
        File('${tempDir.path}/.env').writeAsStringSync(
          env.entries
              .map((MapEntry<String, String> e) => '${e.key}=${e.value}')
              .join('\n'),
        );
        Directory.current = tempDir;

        db = await DbConnection.open(env);
        for (String table in <String>[
          'dox_db_migration',
          'mig_comment',
          'mig_blog',
          'mig_tag',
          'mig_fail',
          'mig_post',
          'mig_user',
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

        await Migrator().migrate();
        expect(await tableExists('mig_blog'), true);
        List<Map<String, dynamic>> rows = await db.execute(
          'SELECT title FROM mig_blog',
        );
        expect(rows.first['title'], 'hello');
        expect(
          (await migrations()).map((Map<String, dynamic> r) => r['batch']),
          <int>[1],
        );

        // nothing new, nothing changes
        await Migrator().migrate();
        expect((await migrations()).length, 1);

        writeMigration('2023_01_02_000000_create_tag', '''
-- up
CREATE TABLE mig_tag (id INTEGER PRIMARY KEY)

-- down
DROP TABLE IF EXISTS mig_tag
''');
        await Migrator().migrate();
        expect(await tableExists('mig_tag'), true);
        expect(
          (await migrations()).map((Map<String, dynamic> r) => r['batch']),
          <int>[1, 2],
        );

        // rollback only undoes the last batch
        await Migrator().rollback();
        expect(await tableExists('mig_tag'), false);
        expect(await tableExists('mig_blog'), true);
        expect(
          (await migrations()).map((Map<String, dynamic> r) => r['batch']),
          <int>[1],
        );

        await Migrator().rollback();
        expect(await tableExists('mig_blog'), false);
        expect(await migrations(), isEmpty);
      });

      test('rollback runs in reverse order, step and reset', () async {
        writeMigration('2023_01_01_000000_create_blog', '''
-- up
CREATE TABLE mig_blog (id INTEGER PRIMARY KEY)

-- down
DROP TABLE mig_blog
''');
        // comment table needs blog table, so it must be dropped first
        writeMigration('2023_01_02_000000_create_comment', '''
-- up
CREATE TABLE mig_comment (
  id INTEGER PRIMARY KEY,
  blog_id INTEGER REFERENCES mig_blog (id)
)

-- down
DROP TABLE mig_comment
''');
        await Migrator().migrate();
        expect(await tableExists('mig_comment'), true);

        await Migrator().rollback();
        expect(await tableExists('mig_comment'), false);
        expect(await tableExists('mig_blog'), false);
        expect(await migrations(), isEmpty);

        await Migrator().migrate();
        writeMigration('2023_01_03_000000_create_tag', '''
-- up
CREATE TABLE mig_tag (id INTEGER PRIMARY KEY)

-- down
DROP TABLE mig_tag
''');
        await Migrator().migrate();

        // step undoes the last n migrations, even across batches
        await Migrator().rollback(step: 2);
        expect(await tableExists('mig_tag'), false);
        expect(await tableExists('mig_comment'), false);
        expect(await tableExists('mig_blog'), true);
        expect(
          (await migrations()).map((Map<String, dynamic> r) => r['migration']),
          <String>['2023_01_01_000000_create_blog'],
        );

        await Migrator().migrate();
        await Migrator().reset();
        expect(await tableExists('mig_blog'), false);
        expect(await migrations(), isEmpty);

        await Migrator().refresh();
        expect(await tableExists('mig_tag'), true);
        expect((await migrations()).length, 3);
      });

      test('sql with dashes, semicolons in strings and comments', () async {
        writeMigration('2023_01_01_000000_create_blog', '''
-- up
-- a normal comment; with a semicolon
CREATE TABLE mig_blog (
  id INTEGER PRIMARY KEY,
  title VARCHAR(255) -- the title
);
/* block comment; with a semicolon */
INSERT INTO mig_blog (id, title) VALUES (1, 'a-b; c -- d');
INSERT INTO mig_blog (id, title) VALUES (2 - 0, 'it''s');

-- down
DROP TABLE mig_blog
''');
        await Migrator().migrate();
        List<Map<String, dynamic>> rows = await db.execute(
          'SELECT id, title FROM mig_blog ORDER BY id',
        );
        expect(
          rows.map((Map<String, dynamic> r) => r['title'].toString()),
          <String>['a-b; c -- d', "it's"],
        );
        await Migrator().rollback();
        expect(await tableExists('mig_blog'), false);
      });

      /// a driver from the app (eg. `SqlQueryBuilder().dbDriver`): the
      /// migration still runs each file in one transaction, and the driver
      /// stays open for the app
      test('migrate with a given driver', () async {
        DBDriver driver = DbConnection.config(env).createDriver();
        addTearDown(driver.close);
        writeMigration('2023_01_01_000000_create_blog', '''
-- up
CREATE TABLE mig_blog (id INTEGER PRIMARY KEY);
INSERT INTO mig_blog (id) VALUES (1)

-- down
DROP TABLE mig_blog
''');
        await Migrator(connection: driver).migrate();
        expect(await tableExists('mig_blog'), true);
        expect((await migrations()).length, 1);
        List<Map<String, dynamic>> rows = await driver.query(
          'SELECT id FROM mig_blog',
        );
        expect(rows.single['id'], 1);
      });

      test('migrate with a config', () async {
        await Migrator(
          migrations: <MigrationEntry>[
            MigrationEntry('2023_01_01_000000_user', CreateUserTable()),
          ],
          config: DbConnection.config(env),
        ).migrate();
        expect(await tableExists('mig_user'), true);
      });

      test('failed migration is not recorded', () async {
        writeMigration('2023_01_01_000000_fail', '''
-- up
CREATE TABLE mig_fail (id INTEGER PRIMARY KEY);
INSERT INTO not_a_table VALUES (1)

-- down
DROP TABLE IF EXISTS mig_fail
''');

        writeMigration('2023_01_02_000000_later', '''
-- up
CREATE TABLE mig_tag (id INTEGER PRIMARY KEY)

-- down
DROP TABLE IF EXISTS mig_tag
''');

        await expectLater(Migrator().migrate(), throwsException);
        expect(await migrations(), isEmpty);
        // stop at the first failure, the later migration does not run
        expect(await tableExists('mig_tag'), false);
        // mysql auto commits DDL, so only postgres rolls back the table
        expect(await tableExists('mig_fail'), driver == 'mysql');
      });

      List<MigrationEntry> dartMigrations = <MigrationEntry>[
        MigrationEntry(
          '2023_01_01_000000_create_user_table',
          CreateUserTable(),
        ),
        MigrationEntry(
          '2023_01_03_000000_create_post_table',
          CreatePostTable(),
        ),
      ];

      test('dart migrations: migrate, status, rollback', () async {
        Migrator migrator = Migrator(migrations: dartMigrations);
        await migrator.migrate();
        expect(await tableExists('mig_user'), true);
        expect(await tableExists('mig_post'), true);
        expect(
          (await migrations()).map((Map<String, dynamic> r) => r['migration']),
          <String>[
            '2023_01_01_000000_create_user_table',
            '2023_01_03_000000_create_post_table',
          ],
        );
        List<MigrationStatus> status = await migrator.status();
        expect(
          status.every((MigrationStatus s) => s.ran && s.batch == 1),
          true,
        );

        await migrator.rollback();
        expect(await tableExists('mig_post'), false);
        expect(await tableExists('mig_user'), false);
        status = await migrator.status();
        expect(status.any((MigrationStatus s) => s.ran), false);
        expect(status.length, 2);
      });

      test('dart and sql migrations in one folder, ordered by name', () async {
        // between the two dart migrations
        writeMigration(
          '2023_01_02_000000_create_tag',
          '-- up\nCREATE TABLE mig_tag (id INTEGER PRIMARY KEY)\n\n'
              '-- down\nDROP TABLE mig_tag\n',
        );
        Migrator migrator = Migrator(migrations: dartMigrations);
        await migrator.migrate();
        expect(
          (await migrations()).map((Map<String, dynamic> r) => r['migration']),
          <String>[
            '2023_01_01_000000_create_user_table',
            '2023_01_02_000000_create_tag',
            '2023_01_03_000000_create_post_table',
          ],
        );
        await migrator.rollback(step: 1);
        expect(await tableExists('mig_post'), false);
        expect(await tableExists('mig_tag'), true);

        await migrator.refresh();
        expect((await migrations()).length, 3);
        await migrator.reset();
        expect(await migrations(), isEmpty);
        expect(await tableExists('mig_user'), false);
      });

      test('change columns of tables with foreign keys', () async {
        List<MigrationEntry> list = <MigrationEntry>[
          ...dartMigrations,
          MigrationEntry('2023_01_04_000000_change_title', ChangePostTitle()),
        ];
        await Migrator(migrations: list).migrate();
        await db.execute(
          "INSERT INTO mig_post (user_id, title) VALUES (1, '${'x' * 150}')",
        );

        // sqlite rebuilds mig_user, the post row must stay
        list.add(
          MigrationEntry('2023_01_05_000000_change_email', ChangeUserEmail()),
        );
        Migrator migrator = Migrator(migrations: list);
        await migrator.migrate();
        List<Map<String, dynamic>> rows = await db.execute(
          'SELECT title FROM mig_post',
        );
        expect(rows.single['title'], 'x' * 150);
        await migrator.rollback(step: 2);
        await migrator.reset();
        expect(await tableExists('mig_post'), false);
        expect(await migrations(), isEmpty);
      });

      test('failed dart migration: error has the name, not recorded', () async {
        Migrator migrator = Migrator(
          migrations: <MigrationEntry>[
            MigrationEntry('2023_01_01_000000_fail', FailingMigration()),
            MigrationEntry('2023_01_02_000000_user', CreateUserTable()),
          ],
        );
        await expectLater(
          migrator.migrate(),
          throwsA(
            isA<MigrationException>().having(
              (MigrationException e) => e.migration,
              'migration',
              '2023_01_01_000000_fail',
            ),
          ),
        );
        expect(await migrations(), isEmpty);
        expect(await tableExists('mig_user'), false);
        // mysql auto commits DDL
        expect(await tableExists('mig_fail'), driver == 'mysql');
        await db.execute('DROP TABLE IF EXISTS mig_fail');
        expect(await migrator.run(<String>['run']), 1);
      });

      test('withinTransaction false still records', () async {
        Migrator migrator = Migrator(
          migrations: <MigrationEntry>[
            MigrationEntry('2023_01_01_000000_user', NoTransaction()),
          ],
        );
        await migrator.migrate();
        expect((await migrations()).length, 1);
        await migrator.rollback();
        expect(await tableExists('mig_user'), false);
      });

      test('run() commands and exit codes', () async {
        Migrator migrator = Migrator(migrations: dartMigrations);
        expect(await migrator.run(<String>['migration:run']), 0);
        expect(await migrator.run(<String>['status']), 0);
        expect(await migrator.run(<String>['rollback', '--step=1']), 0);
        expect(await tableExists('mig_post'), false);
        expect(await migrator.run(<String>['rollback', '--step', '1']), 0);
        expect(await tableExists('mig_user'), false);
        expect(await migrator.run(<String>['refresh']), 0);
        expect(await migrator.run(<String>['reset']), 0);
        expect(await migrator.run(<String>['rollback', '--step=x']), 1);
        expect(await migrator.run(<String>['nope']), 1);
        expect(await migrations(), isEmpty);
      });

      test('same name as dart and sql throws', () async {
        writeMigration('2023_01_01_000000_create_user_table', '-- up\n-- down');
        await expectLater(
          Migrator(migrations: dartMigrations).migrate(),
          throwsStateError,
        );
      });

      test('status shows a missing file', () async {
        await Migrator(migrations: dartMigrations).migrate();
        List<MigrationStatus> status = await Migrator(
          migrations: <MigrationEntry>[
            MigrationEntry('2023_01_01_000000_user', CreateUserTable()),
          ],
        ).status();
        expect(status.last.exists, false);
        expect(status.last.ran, true);
        await Migrator(migrations: dartMigrations).reset();
      });
    });
  }
}

class CreateUserTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('mig_user', (Table table) {
      table.id();
      table.string('email').unique();
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) => schema.dropIfExists('mig_user');
}

class CreatePostTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('mig_post', (Table table) {
      table.id();
      table.foreignId('user_id').constrained('mig_user').cascadeOnDelete();
      table.string('title', 50);
    });
    await schema.driver.execute(
      "INSERT INTO mig_user (email) VALUES ('a@b.c')",
    );
  }

  @override
  Future<void> down(Schema schema) => schema.dropIfExists('mig_post');
}

/// change() on sqlite rebuilds mig_post, it points to mig_user
class ChangePostTitle extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.table('mig_post', (Table table) {
      table.string('title', 200).nullable().change();
      table.text('body').nullable();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.table('mig_post', (Table table) {
      table.dropColumn('body');
    });
  }
}

/// change() on sqlite rebuilds mig_user, mig_post points to it
class ChangeUserEmail extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.table('mig_user', (Table table) {
      table.string('email', 120).change();
    });
  }

  @override
  Future<void> down(Schema schema) async {}
}

class FailingMigration extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('mig_fail', (Table table) => table.id());
    await schema.driver.execute('INSERT INTO not_a_table VALUES (1)');
  }

  @override
  Future<void> down(Schema schema) => schema.dropIfExists('mig_fail');
}

class NoTransaction extends CreateUserTable {
  @override
  bool get withinTransaction => false;
}

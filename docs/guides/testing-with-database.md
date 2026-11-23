---
icon: lucide/flask-conical
---

# Testing with a database

Run model tests against a real database: SQLite for fast local tests, or a test Postgres for the real thing.

A real database finds bugs that a mock can not find, like a wrong column name. The migrations run one time, and every test starts with empty tables.

## What you need

- A Dox app (`dox create my_app`). A new app has the `User` model, a `users` migration in `db/migration` and the `test` package.

## 1. Check the migration

The test makes its tables from your migrations. A new app has this one, with another date in the file name:

```dart title="db/migration/2026_10_22_000000_create_users_table.dart"
import 'package:dox_migration/dox_migration.dart';

class CreateUsersTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('users', (Table table) {
      table.id();
      table.string('name');
      table.string('email').unique();
      table.string('password');
      table.timestamps();
      table.softDeletes();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('users');
  }
}
```

The test imports the list of all migrations from `db/migration/migrations.dart`. `dox make:migration` updates this list.

## 2. Write the test (SQLite)

Start with SQLite, because it needs no server. The test has its own database config:

```dart title="test/user_test.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_orm/dox_orm.dart';
import 'package:dox_orm/testing.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

/// One SQLite file for this test file. No server, no Postgres.
const String dbFile = 'storage/test.sqlite';

DatabaseConfig testDatabase = DatabaseConfig(
  connection: 'sqlite',
  connections: <String, ConnectionConfig>{
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: dbFile,
      debug: false,
    ),
  },
);

Future<void> deleteDbFile() async {
  for (String suffix in <String>['', '-wal', '-shm']) {
    File file = File('$dbFile$suffix');
    if (await file.exists()) await file.delete();
  }
}

void main() {
  setUpAll(() async {
    await deleteDbFile();
    await Migrator(
      migrations: migrations,
      config: testDatabase.getConnectionConfig(),
    ).migrate();
    SqlQueryBuilder.initializeWithDatabaseConfig(testDatabase);
  });

  // every test starts with empty tables
  setUp(refreshDatabase);

  tearDownAll(() async {
    await deleteDbFile();
  });

  test('saves and finds a user', () async {
    User user = User()
      ..name = 'Ann'
      ..email = 'ann@example.com'
      ..password = Hash.make('secret123');
    await user.save();

    User? found = await User().where('email', 'ann@example.com').getFirst();
    expect(found?.id, user.id);
    expect(found?.name, 'Ann');
    expect(Hash.verify('secret123', found!.password!), isTrue);
  });

  test('the tables are empty again', () async {
    expect(await User().count(), 0);
  });
}
```

`refreshDatabase()` empties every table except the migrations table, and starts the ids at 1 again.

Put `storage/test.sqlite` in `.gitignore`. Use a file, not `:memory:`, because the migrator and the ORM each open their own connection.

## 3. Run it

Run the test file:

```bash
dart test test/user_test.dart
```

## Check it

The migrations run, and then the tests pass:

```text
00:00 +0: (setUpAll)
Migrating: 2026_10_22_000000_create_users_table
Migrated: 2026_10_22_000000_create_users_table
Migrating: 2026_10_23_000000_create_queue_tables
Migrated: 2026_10_23_000000_create_queue_tables
00:00 +1: saves and finds a user
00:00 +2: the tables are empty again
00:00 +2: All tests passed!
```

## The same test on Postgres

If your app runs on Postgres in production, test on Postgres too. Use a separate database for tests, because the tests delete all rows.

Start a test database with Docker:

```bash
docker run -d --name my_app_test -p 5433:5432 \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=my_app_test postgres:18
```

Change the config at the top of the test:

```dart
DatabaseConfig testDatabase = DatabaseConfig(
  connection: 'postgres',
  connections: <String, ConnectionConfig>{
    'postgres': ConnectionConfig(
      driver: Driver.postgres,
      host: 'localhost',
      port: 5433,
      user: 'postgres',
      password: 'postgres',
      database: 'my_app_test',
      debug: false,
    ),
  },
);
```

Delete `deleteDbFile()` and its two calls. The rest of the test stays the same.

## Many test files

Test files run at the same time, so two files that use the same table can break each other. Give each file its own SQLite file, or run the files one by one:

```bash
dart test --concurrency=1
```

## Test a route with the database

This test uses the `/api/users` route of the [Pagination](pagination.md) guide. `DoxTestClient` starts the app in the test, with the config in `lib/config/database.dart`:

```dart title="test/api_test.dart"
import 'package:dox_core/testing.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_orm/testing.dart';
import 'package:my_app/config/app.dart';
import 'package:my_app/config/database.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
    client = await DoxTestClient.start(appConfig);
  });

  setUp(refreshDatabase);

  tearDownAll(() async {
    await client.close();
  });

  test('GET /api/users has no rows', () async {
    TestResponse res = await client.get('/api/users');
    res.expectStatus(200);
    expect(res.json['data'], isEmpty);
  });
}
```

Pick the test database with env variables:

```bash
DB_CONNECTION=sqlite DB_NAME=storage/test.sqlite \
    dart test test/api_test.dart
```

## Next steps

- [Testing: test HTTP routes](../digging-deeper/testing.md#test-http-routes): all the client methods.
- [Migration](../database/migration.md): write migrations.
- [Database: SQLite](../database/index.md#sqlite): the SQLite settings.

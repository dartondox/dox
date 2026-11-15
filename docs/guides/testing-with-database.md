---
icon: lucide/flask-conical
---

# Testing with a database

Run model tests against a real database: SQLite for fast local tests, or a test Postgres for the real thing.

A test with a real database finds bugs that a mock can not find, like a wrong column name or a broken query. In this guide the migrations run once, and every test starts with empty tables, so the tests do not change each other's data.

## What you need

- A Dox app (`dox create my_app`). A new app has the `User` model, a `users` migration in `db/migration` and the `test` package.

## 1. Check the migration

The test builds its tables from your migrations. A new app has this one (its file name starts with another date). For a new table, run `dox make:migration create_posts_table`.

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

`db/migration/migrations.dart` is the list of all migrations, and `dox make:migration` updates it. The test imports that list. Because a Dart migration works on Postgres, MySQL and SQLite, the same test runs on all of them.

## 2. Write the test (SQLite)

Start with SQLite, because it needs no server. The test makes its own database config, so your `.env` does not matter.

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

This is what happens:

1. `setUpAll` deletes an old database file, runs the migrations, and starts the ORM on the same file.
2. `setUp` runs `refreshDatabase()` before each test. It empties every table (not the migrations table) and starts the ids at 1 again.
3. `tearDownAll` deletes the file.

Put `storage/test.sqlite` in `.gitignore`. The test uses a file and not `:memory:`, because the migrator and the ORM each open their own connection. Two connections to `:memory:` are two different databases.

## 3. Run it

```bash
dart test test/user_test.dart
```

## Check it

You see the migrations run, and then the tests pass. The migration names start with the dates of your files, and a new app also has the tables of the queue:

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

SQLite is fast, but your app may run on Postgres in production. Then you should test on Postgres too. Use a separate database for tests, never the one you develop on, because the tests delete all rows.

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

Delete `deleteDbFile()` and its two calls. The rest of the test stays the same. You can also read these values from the env, and run `DB_PORT=5433 DB_NAME=my_app_test dart test`.

## Many test files

Each test file runs in its own process, at the same time as the others. So two files that use the same table can break each other. To fix it, give each file its own SQLite file (`storage/test_users.sqlite`, `storage/test_posts.sqlite`), or run the files one by one:

```bash
dart test --concurrency=1
```

## Test a route with the database

You can also test a full route, from the request to the database. This test uses the `GET /api/users` route of the [Pagination](pagination.md) guide.

`DoxTestClient` starts the app inside the test. It runs the providers, so the ORM uses the config in `lib/config/database.dart`. So you pick the test database with env variables:

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

```bash
DB_CONNECTION=sqlite DB_NAME=storage/test.sqlite dart test test/api_test.dart
```

See [Testing: test HTTP routes](../digging-deeper/testing.md#test-http-routes) for all client methods.

## See also

- [Testing](../digging-deeper/testing.md)
- [Migration](../database/migration.md)
- [Database: SQLite](../database/index.md#sqlite)

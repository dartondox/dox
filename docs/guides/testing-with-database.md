# Testing with a database

Run model tests against a real database, SQLite or a test Postgres, with migrations run once and an empty table for every test.

## What you need

- A Dox app with Dart migrations in `db/migration` (see [Migration](../database/migration.md)).
- `test` as a dev dependency: `dart pub add dev:test`.

## 1. Write the migration

If you do not have one yet:

```bash
dox make:migration create_users_table
```

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

The command also writes `db/migration/migrations.dart`, the list of all migrations. The test imports that list.
A Dart migration works on Postgres, MySQL and SQLite, so the same test runs on all of them.

## 2. Write the test (SQLite)

SQLite needs no server. The test makes its own config, so your `.env` does not matter.

```dart title="test/user_test.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_orm/dox_orm.dart';
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

  // every test starts with an empty table
  setUp(() async {
    await User().truncate();
  });

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

  test('the table is empty again', () async {
    expect(await User().count(), 0);
  });
}
```

What happens:

1. `setUpAll` deletes an old database file, runs the migrations, and starts the ORM on the same file.
2. `setUp` empties the table before each test. `truncate()` also resets the id counter.
3. `tearDownAll` deletes the file.

!!! note "A file, not `:memory:`"
    The migrator and the ORM each open their own connection.
    Two connections to `:memory:` are two different databases. A file is shared.
    Put `storage/test.sqlite` in `.gitignore`.

## 3. Run it

```bash
dart test test/user_test.dart
```

## Check it

```text
00:00 +0: (setUpAll)
Migrating: 2026_10_22_000000_create_users_table
Migrated: 2026_10_22_000000_create_users_table
00:00 +1: saves and finds a user
00:00 +2: the table is empty again
00:00 +2: All tests passed!
```

## The same test on Postgres

Use a separate database for tests. Never the one you develop on.

Start one with Docker:

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

Delete `deleteDbFile()` and its two calls. The rest is the same.
Or read the values from the env, and run `DB_PORT=5433 DB_NAME=my_app_test dart test`.

## Many test files

Each test file runs in its own process. Two files that use the same table at the same time break each other.
Either give each file its own SQLite file (`storage/test_users.sqlite`, `storage/test_posts.sqlite`), or run them one by one:

```bash
dart test --concurrency=1
```

## Test a route with the database

Start the server in `setUpAll` and send real requests. The server runs the services, so the ORM is set up by `ORMService`.
Set the database with env variables, so `lib/config/database.dart` picks the test database:

```bash
DB_CONNECTION=sqlite DB_NAME=storage/test.sqlite APP_PORT=3999 dart test test/api_test.dart
```

See [Testing: test HTTP routes](../digging-deeper/testing.md#test-http-routes) for the server setup.

## See also

- [Testing](../digging-deeper/testing.md)
- [Migration](../database/migration.md)
- [Database: SQLite](../database/index.md#sqlite)

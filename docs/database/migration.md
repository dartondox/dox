---
icon: lucide/git-compare-arrows
---

# Migration

A migration changes your database schema step by step, with an `up` method that makes the change and a `down` method that undoes it.

You write migrations in Dart with the [schema builder](schema.md), so one migration works on Postgres, MySQL, MariaDB and SQLite. Plain `.sql` migrations work too.

## Setup

The migration commands read the database from `.env` and the environment variables. An environment variable wins over `.env`:

```bash title=".env"
DB_CONNECTION=postgres # or mysql (also MariaDB), or sqlite
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USERNAME=admin
DB_PASSWORD=password
```

For SQLite, you need only two keys:

```bash title=".env"
DB_CONNECTION=sqlite
DB_NAME=db/dox.sqlite # file path, made if missing
```

### Database settings

Without `DB_CONNECTION`, the migrations use SQLite. `DB_DATABASE` works in place of `DB_NAME`. `DATABASE_URL` wins over all `DB_*` keys, see [`DATABASE_URL`](index.md#database_url). Migrations use TLS only with a `DATABASE_URL` that has sslmode (Postgres) or ssl (MySQL).

`bin/migrate.dart` does not start the ORM. To give the [ORM flags](index.md#orm-flags) to the schema of each migration, pass them to the migrator:

```dart title="bin/migrate.dart"
Future<void> main(List<String> args) async {
  exitCode = await Migrator(
    migrations: migrations,
    flags: databaseConfig.flags,
  ).run(args);
}
```

## Generating migrations

`make:migration` makes a new migration file:

```bash
dox make:migration create_users_table
```

This makes `db/migration/2026_10_21_120000_create_users_table.dart`. The numbers are the date and time, so the migrations run in the right order. The name decides what the file has:

| Name | The file has |
|---|---|
| `create_users_table` | `schema.create('users', ...)` in `up`, and `dropIfExists('users')` in `down` |
| `add_avatar_to_users_table` (also `_from_`, `_in_`, `_on_`) | `schema.table('users', ...)` in `up` and `down` |
| any other name | empty `up` and `down` |

`dox make:model Blog -m` makes a model and its `create_blogs_table` migration.

## Migration structure

`up` adds tables, columns or indexes. `down` undoes what `up` did:

```dart title="db/migration/2026_10_21_120000_create_users_table.dart"
import 'package:dox_migration/dox_migration.dart';

class CreateUsersTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('users', (Table table) {
      table.id();
      table.string('email').unique();
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('users');
  }
}
```

See [Schema](schema.md) for all column types.

### Running raw SQL

`schema.driver` runs SQL on the connection and transaction of the migration:

```dart
await schema.driver.execute("UPDATE users SET role = 'admin' WHERE id = 1");
```

Do not use models or `QueryBuilder` in a migration, because they use another connection.

## Running migrations

`migration:run` runs the migrations that did not run yet. `dox migrate` is the short name:

```bash
dox migration:run
dox migrate --seed # also run the seeders
```

If a migration fails, the command shows its name and exits with code 1. The later migrations do not run.

### Checking the status

`migration:status` shows each migration, its batch, and if it ran:

```bash
dox migration:status
```

### Rolling back migrations

`migration:rollback` undoes the last batch: the migrations of one run. `--step` undoes a number of migrations, and `--batch` undoes one batch:

```bash
dox migration:rollback
dox migration:rollback --step=2
dox migration:rollback --batch=3
```

`migration:reset` undoes all migrations:

```bash
dox migration:reset
```

### Refreshing the database

`migration:refresh` undoes all migrations and runs them again. `migration:fresh` drops all tables and runs all migrations:

```bash
dox migration:refresh
dox migration:fresh --seed
```

!!! warning
    `migration:fresh` also drops tables that no migration made. Do not run it on a database that you share with other apps.

### Running in production

With `APP_ENV=production`, the commands that drop tables ask first. `--force` skips the question:

```bash
dox migration:fresh --force
```

With no terminal, like in CI, they print a warning and run.

### Run on server start

The AOT server binary can run the migrations itself. The app template already does this:

```dart title="bin/server.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:my_app/config/app.dart';
import 'package:my_app/config/database.dart';

import '../db/migration/migrations.dart';

void main() async {
  Dox().initialize(appConfig);
  await Migrator(
    migrations: migrations,
    config: databaseConfig.getConnectionConfig(),
  ).migrate();
  await Dox().startServer();
}
```

It uses the config of the app, so it works without `.env`. If you have `.sql` migrations, keep the `db/migration` folder next to the binary.

## Transactions

Each migration runs in one transaction. On Postgres and SQLite, a failed migration undoes all its changes.

!!! warning "MySQL"
    On MySQL and MariaDB, CREATE, ALTER and DROP save right away. If a migration fails half way, these changes stay. Keep each MySQL migration to one table change.

For SQL that can not run in a transaction, like `CREATE INDEX CONCURRENTLY`, set `withinTransaction` to false:

```dart
class AddSearchIndex extends Migration {
  @override
  bool get withinTransaction => false;

  @override
  Future<void> up(Schema schema) async {
    await schema.driver.execute(
      'CREATE INDEX CONCURRENTLY posts_title_index ON posts (title)',
    );
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.driver
        .execute('DROP INDEX CONCURRENTLY posts_title_index');
  }
}
```

On SQLite, foreign key checks are off while a migration runs. At the end, the migration fails if a foreign key is broken.

## SQL migrations

Use a `.sql` migration for SQL that only one database knows:

```bash
dox make:migration create_blog_table --sql
```

Put the up SQL under a `-- up` line and the down SQL under a `-- down` line:

```sql
-- up
CREATE TABLE IF NOT EXISTS blog (
    id serial PRIMARY KEY,
    title VARCHAR(255) NOT NULL
);

-- down
DROP TABLE IF EXISTS blog
```

Dart and `.sql` migrations run together in file name order. A Dart and a `.sql` migration with the same name is an error.

!!! warning "SQLite ids"
    On SQLite, `id serial PRIMARY KEY` does not make an auto increment id. Use `id INTEGER PRIMARY KEY AUTOINCREMENT`. `table.id()` in Dart does this for you.

## The migration list

An AOT build can not load a file at run time, so Dox keeps a list of the Dart migrations in `db/migration/migrations.dart`. `dox make:migration` and every `dox migration:*` command write it again, so do not edit it:

```dart
import 'package:dox_migration/dox_migration.dart';

import '2026_10_21_120000_create_users_table.dart' as m1;

final List<MigrationEntry> migrations = <MigrationEntry>[
  MigrationEntry(
    '2026_10_21_120000_create_users_table',
    m1.CreateUsersTable(),
  ),
];
```

The migrations that ran are in the `dox_db_migration` table.

## The Migrator class

The `dox migration:*` commands run `bin/migrate.dart`, which calls `Migrator.run`:

```dart title="bin/migrate.dart"
Future<void> main(List<String> args) async {
  exitCode = await Migrator(migrations: migrations).run(args);
}
```

`run` takes `run`, `rollback --step=2`, `reset`, `refresh`, `fresh` or `status`, so `dart run bin/migrate.dart status` works too.

### Where it runs

With `config`, the migrator opens that database and closes it at the end. With `connection`, it uses a driver that is open, and does not close it:

```dart
Migrator(migrations: migrations,
    config: databaseConfig.getConnectionConfig());
Migrator(migrations: migrations, connection: SqlQueryBuilder().dbDriver);
```

With neither, it reads `.env`. `directory` sets the folder of the `.sql` migrations, `db/migration` by default.

### Running from code

Each command is also a method:

```dart
Migrator migrator = Migrator(migrations: migrations);
await migrator.migrate();
await migrator.rollback(step: 2); // or batch: 3
await migrator.reset();
await migrator.refresh();
await migrator.fresh();

List<MigrationStatus> list = await migrator.status();
Migrator.printStatus(list);
```

A `MigrationStatus` has `name`, `batch` (null when it did not run), `ran` and `exists` (false when its file is gone). A failed migration throws a `MigrationException` with the `migration` name and the `error`.

## Next steps

- [Schema](schema.md): all table and column methods.
- [Seeders](seeders.md): put data in the database.
- [Database](index.md): connections and settings.

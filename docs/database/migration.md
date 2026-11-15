---
icon: lucide/git-compare-arrows
---

# Migration

A migration changes your database schema step by step, with an `up` method that makes the change and a `down` method that undoes it.

Migrations are like version control for your database. Your team can share the same schema, and every server can build it with one command. You write migrations in Dart with the [schema builder](schema.md), so the same migration works on Postgres, MySQL, MariaDB and SQLite. Plain `.sql` migrations work too.

## Generating migrations

Use the `make:migration` command to make a new migration:

```bash
dox make:migration create_users_table
```

This makes `db/migration/2026_10_21_120000_create_users_table.dart`. The numbers are the date and time when you run the command, so Dox can run the migrations in the right order.

The name of the migration decides what the new file contains:

| Name | The file has |
|---|---|
| `create_users_table` | `schema.create('users', ...)` in `up`, and `dropIfExists('users')` in `down` |
| `add_avatar_to_users_table` (also `_from_`, `_in_`, `_on_`) | `schema.table('users', ...)` in `up` and `down` |
| any other name | empty `up` and `down` |

If you also want a model, `dox make:model Blog -m` makes the model and a `create_blogs_table` migration.

## Migration structure

A migration class has two methods. The `up` method adds tables, columns or indexes. The `down` method undoes what `up` did:

```dart title="db/migration/2026_10_21_120000_create_users_table.dart"
import 'package:dox_migration/dox_migration.dart';

class CreateUsersTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('users', (Table table) {
      table.id();
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('users');
  }
}
```

Add your columns in `up`, for example `table.string('email').unique();`. See [Schema](schema.md) for all column types.

### Running raw SQL

Sometimes you need SQL that the schema builder does not have, or you want to change data. Use `schema.driver`, because it runs on the same connection and transaction as the migration:

```dart
await schema.driver.execute("UPDATE users SET role = 'admin' WHERE id = 1");
```

Do not use models or `QueryBuilder` in a migration, because they use another connection.

## Running migrations

Use `migration:run` to run all migrations that did not run yet:

```bash
dox migration:run
```

The short name `dox migrate` works too. If you want to run the [seeders](seeders.md) after it, add `--seed`.

If a migration fails, the error shows its name and the command exits with code `1`. The failed migration is not saved, and the later ones do not run.

### Checking the status

The `migration:status` command shows each migration, its batch, and if it ran:

```bash
dox migration:status
```

### Rolling back migrations

To undo the last batch, use `migration:rollback`. A batch is the group of migrations that ran in one `migration:run`:

```bash
dox migration:rollback
```

Use `--step` to undo a number of migrations, even across batches. Use `--batch` to undo only one batch:

```bash
dox migration:rollback --step=2

dox migration:rollback --batch=3
```

To undo all migrations, use `migration:reset`:

```bash
dox migration:reset
```

### Refreshing the database

`migration:refresh` undoes all migrations and then runs them again:

```bash
dox migration:refresh
```

`migration:fresh` drops all tables and then runs all migrations. It also drops tables that no migration made, so do not run it on a database you share with other apps:

```bash
dox migration:fresh
```

Both commands also take `--seed`.

### Running in production

When `APP_ENV=production`, `migration:rollback`, `migration:reset`, `migration:refresh` and `migration:fresh` ask before they drop tables. Type `y` to go on. Add `--force` to skip the question:

```bash
dox migration:fresh --force
```

With no terminal, like in CI or a deploy script, they print a warning and run.

### Run on server start

The AOT server binary can run the migrations itself, because the migration list is compiled in. The new app template already does this:

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

It uses the config from `lib/config/database.dart`, so it also works without a `.env` file. If you also have `.sql` migrations, keep the `db/migration` folder next to the binary.

## Database settings

The migration commands read the database from the `.env` file and the environment variables. A real environment variable wins over `.env`.

```bash title=".env"
DB_CONNECTION=postgres # or mysql (also MariaDB), or sqlite
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USERNAME=admin
DB_PASSWORD=password
```

For SQLite, you only need two keys:

```bash title=".env"
DB_CONNECTION=sqlite
DB_NAME=db/dox.sqlite # file path, made if missing
```

Without `DB_CONNECTION`, the migrations use `sqlite`. When `DATABASE_URL` is set, it wins over all `DB_*` keys. See [`DATABASE_URL`](index.md#database_url).

## Transactions

Each migration runs in one transaction. On Postgres and SQLite, a failed migration undoes all its changes.

!!! warning "MySQL"
    On MySQL and MariaDB, `CREATE`, `ALTER` and `DROP` save right away. So if a migration fails half way, these changes stay. Only data changes are undone. Keep each MySQL migration small: one table change per migration.

Some SQL can not run in a transaction, like `CREATE INDEX CONCURRENTLY` on Postgres. For this, set `withinTransaction` to `false`:

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
    await schema.driver.execute('DROP INDEX CONCURRENTLY posts_title_index');
  }
}
```

## SQL migrations

Use a `.sql` migration when you need SQL that only one database understands:

```bash
dox make:migration create_blog_table --sql
```

Put the `up` SQL under a `-- up` line and the `down` SQL under a `-- down` line. Each of these markers must be on its own line:

```sql
-- up
CREATE TABLE IF NOT EXISTS blog (
    id serial PRIMARY KEY,
    title VARCHAR(255) NOT NULL
);

-- down
DROP TABLE IF EXISTS blog
```

Dart and `.sql` migrations can live together in `db/migration`. They run in file name order, so by their timestamp. A Dart and a `.sql` migration with the same name is an error.

!!! warning "SQLite ids"
    In SQLite, `id serial PRIMARY KEY` does not make an auto increment id. The id stays `NULL`. Use `id INTEGER PRIMARY KEY AUTOINCREMENT` for SQLite. `table.id()` in Dart does this for you.

## Details

This section is for special cases. Most apps do not need it.

### The migration list

An AOT build can not load a file at run time. So Dox keeps a list of your Dart migrations in `db/migration/migrations.dart`:

```dart
// Made by `dox make:migration` and the `dox migration:*` commands.
// Do not edit, it is made again from the files in this folder.
import 'package:dox_migration/dox_migration.dart';

import '2026_10_21_120000_create_users_table.dart' as m1;

final List<MigrationEntry> migrations = <MigrationEntry>[
  MigrationEntry(
    '2026_10_21_120000_create_users_table',
    m1.CreateUsersTable(),
  ),
];
```

`dox make:migration` and every `dox migration:*` command write this file again, so you do not edit it. It lists each file named `YYYY_MM_DD_HHMMSS_name.dart` and its `class ... extends Migration`.

The first `dox make:migration` also makes `bin/migrate.dart`. The `dox migration:*` commands run `dart run bin/migrate.dart <command>`, so your migrations run as part of your app code:

```dart
import 'dart:io';

import 'package:dox_migration/dox_migration.dart';

import '../db/migration/migrations.dart';

Future<void> main(List<String> args) async {
  exitCode = await Migrator(migrations: migrations).run(args);
}
```

### Other cases

- `create:migration` is the same as `make:migration`.
- `migrate:rollback`, `migrate:reset`, `migrate:refresh`, `migrate:fresh` and `migrate:status` are short names.
- You can run `dart run bin/migrate.dart run` (or `rollback --step=2`, `reset`, `refresh`, `status`) yourself.
- The name of a migration is its file name without `.dart`. Migrations run in name order and are undone newest first.
- The migrations that ran are saved in the `dox_db_migration` table.
- If the file of a migration that ran is gone, rollback prints `Migration not found: <name>`, keeps its row and rolls back the others.
- A project with only `.sql` files and no `bin/migrate.dart` is run by `dox` itself.
- In `.sql` files, other `--` lines are normal comments. Statements are split on `;`, but not on a `;` inside quotes, comments or a Postgres `$$ ... $$` body.
- `.env` is read like `Env.get()` reads it (`export`, comments, quotes), but with no `${VAR}` expansion. `.env.testing` is not read.
- `DB_DATABASE` works in place of `DB_NAME`. The default port is `5432` for Postgres and `3306` for MySQL.
- A `DB_HOST` that starts with `/` is a [Unix socket](index.md#unix-socket).
- Migrations use TLS only with a `DATABASE_URL` that has `sslmode` (Postgres) or `ssl` (MySQL), like `?sslmode=require`.
- One run opens one driver and closes it at the end. Each migration runs on one connection.
- On SQLite, foreign key checks are off while a migration runs, so Dox can make a table again (see [SQLite notes](schema.md#sqlite-notes)). Before the end, Dox checks all foreign keys, and the migration fails if one is broken.
- `Migrator(migrations: migrations, config: databaseConfig.getConnectionConfig())` opens this config and closes it at the end.
- `Migrator(migrations: migrations, connection: SqlQueryBuilder().dbDriver)` runs on a driver that is already open. The migrator does not close it.
- `Migrator(migrations: migrations, flags: databaseConfig.flags)` gives the [ORM flags](index.md#orm-flags) to the `Schema` of each migration. Without it, the migrator uses `SqlQueryBuilder().flags`.

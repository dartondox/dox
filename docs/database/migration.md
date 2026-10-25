---
icon: lucide/git-compare-arrows
---

# Migration

A migration changes your database schema step by step, with an `up` method that makes the change and a `down` method that undoes it.

Write migrations in Dart with the [schema builder](schema.md).
The same migration then works on Postgres, MySQL, MariaDB and SQLite.
Plain `.sql` migrations work too.

## Create a migration

```bash
dox make:migration create_users_table
```

This makes `db/migration/2026_10_21_120000_create_users_table.dart`.
The numbers are the date and time when you run the command.

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

Add your columns in `up`, for example `table.string('email').unique();`.
See [Schema](schema.md) for all column types.

The name of the migration decides what the new file contains:

| Name | The file has |
|---|---|
| `create_users_table` | `schema.create('users', ...)` in `up`, and `dropIfExists('users')` in `down` |
| `add_avatar_to_users_table` (also `_from_`, `_in_`, `_on_`) | `schema.table('users', ...)` in `up` and `down` |
| any other name | empty `up` and `down` |

- `create:migration` does the same.
- `dox make:model Blog -m` makes the model and a `create_blogs_table` migration.

!!! info "Raw SQL and data in a Dart migration"
    `schema.driver` runs raw SQL on the same connection and transaction:
    `await schema.driver.execute("UPDATE users SET role = 'admin' WHERE id = 1");`
    Do not use models or `QueryBuilder` in a migration. They use another connection.

## The registry

An AOT build can not load a file at run time.
So Dox keeps a list of your Dart migrations in `db/migration/migrations.dart`:

```dart
// Made by `dox make:migration` and the `dox migration:*` commands.
import 'package:dox_migration/dox_migration.dart';

import '2026_10_21_120000_create_users_table.dart' as m1;

final List<MigrationEntry> migrations = <MigrationEntry>[
  MigrationEntry(
    '2026_10_21_120000_create_users_table',
    m1.CreateUsersTable(),
  ),
];
```

- `dox make:migration` and every `dox migration:*` command write this file again.
  You do not edit it.
- It lists each file named `YYYY_MM_DD_HHMMSS_name.dart` and its `class ... extends Migration`.
- The name of a migration is its file name without `.dart`. The order is by name.

The first `dox make:migration` also makes `bin/migrate.dart` in your app:

```dart
import 'dart:io';

import 'package:dox_migration/dox_migration.dart';

import '../db/migration/migrations.dart';

Future<void> main(List<String> args) async {
  exitCode = await Migrator(migrations: migrations).run(args);
}
```

The `dox migration:*` commands run `dart run bin/migrate.dart <command>`.
So your migrations run as part of your app code.

## Run migrations

| Command | What it does |
|---|---|
| `dox migration:run` | Run the migrations that did not run yet. Short name: `dox migrate`. |
| `dox migration:rollback` | Undo the last batch. |
| `dox migration:rollback --step=2` | Undo the last 2 migrations, even across batches. |
| `dox migration:reset` | Undo all migrations. |
| `dox migration:refresh` | Undo all migrations, then run them again. |
| `dox migration:fresh` | Drop all tables, then run all migrations. It also drops tables that no migration made. |
| `dox migration:status` | Show each migration, its batch, and if it ran. |

`migrate:rollback`, `migrate:reset`, `migrate:refresh`, `migrate:fresh` and `migrate:status` are short names.

Add `--seed` to `migration:run`, `migration:refresh` or `migration:fresh` to run the [seeders](seeders.md) after it.

A batch is the group of migrations that ran in one `migration:run`.
Migrations are undone newest first.
The ran migrations are saved in the `dox_db_migration` table.

When a migration fails, the error shows its name, and the command exits with code `1`.
The failed migration is not saved, and the later ones do not run.

You can also run `dart run bin/migrate.dart run` (or `rollback --step=2`, `reset`, `refresh`, `status`) yourself.

### Run on server start

The AOT server binary can run the migrations, because the registry is compiled in.
The new app template already does this:

```dart title="bin/server.dart"
import 'package:my_app/config/app.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';

import '../db/migration/migrations.dart';

void main() async {
  Dox().initialize(appConfig);
  await Migrator(migrations: migrations).migrate();
  await Dox().startServer();
}
```

Keep the `db/migration` folder next to the binary if you also have `.sql` migrations.

## Database settings

The migrations read the `.env` file and the environment variables.
A real environment variable wins over `.env`, the same as `Env.get()`.

When `DATABASE_URL` is set, it wins over all `DB_*` keys. See [`DATABASE_URL`](index.md#database_url).

```bash title=".env"
DB_CONNECTION=postgres # or mysql (also MariaDB), or sqlite
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USERNAME=admin
DB_PASSWORD=password
```

For SQLite, only two variables are needed:

```bash title=".env"
DB_CONNECTION=sqlite
DB_NAME=storage/app.db # file path, made if missing
```

- `DB_DATABASE` works too, in place of `DB_NAME`.
- The default port is `5432` for Postgres and `3306` for MySQL.
- One run opens one driver and closes it at the end. Each migration runs on one connection.
- A `DB_HOST` that starts with `/` is a [Unix socket](index.md#unix-socket).
- Migrations use TLS only with a `DATABASE_URL` that has `sslmode` (Postgres) or `ssl` (MySQL), like `?sslmode=require`. The url options are on the [Database](index.md#database_url) page.

You can also give the database yourself:

- `Migrator(migrations: migrations, config: databaseConfig.getConnectionConfig())` opens this config, and closes it at the end.
- `Migrator(migrations: migrations, connection: SqlQueryBuilder().dbDriver)` runs on a driver that is already open. The migrator does not close it.

## Transactions

Each migration runs in one transaction.
On Postgres and SQLite, a failed migration undoes all its changes.

!!! warning "MySQL"
    On MySQL and MariaDB, `CREATE`, `ALTER` and `DROP` save right away.
    So if a migration fails half way, these changes stay. Only data changes are undone.
    Keep each MySQL migration small: one table change per migration.

To run a migration without a transaction (for example `CREATE INDEX CONCURRENTLY` on Postgres):

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

!!! info "SQLite foreign keys"
    On SQLite, foreign key checks are off while a migration runs.
    This lets Dox make a table again (see [SQLite notes](schema.md#sqlite-notes)).
    Before the end, Dox checks all foreign keys. The migration fails if one is broken.

## SQL migrations

Use a `.sql` migration for SQL that only one database understands.

```bash
dox make:migration create_blog_table --sql
```

```sql
-- up
CREATE TABLE IF NOT EXISTS blog (
    id serial PRIMARY KEY,
    title VARCHAR(255) NOT NULL
);

-- down
DROP TABLE IF EXISTS blog
```

- Put the `up` SQL under a line `-- up`, and the `down` SQL under a line `-- down`.
  Each of these lines must be on its own line. Other `--` lines are normal SQL comments.
- Statements are split on `;`.
  A `;` inside quotes, comments or a postgres `$$ ... $$` body does not split.

!!! warning "SQLite ids"
    In SQLite, `id serial PRIMARY KEY` does not make an auto increment id. The id stays `NULL`.
    Use `id INTEGER PRIMARY KEY AUTOINCREMENT` for SQLite. `table.id()` in Dart does this for you.

### Dart and SQL in one folder

Both kinds can live in `db/migration`. They run in file name order (the timestamp).

- With `bin/migrate.dart`: the Migrator runs the Dart migrations from the registry
  and reads the `.sql` files from the folder, merged by name.
- Without `bin/migrate.dart` (a project with only `.sql` files): `dox` runs the `.sql` files itself.
- A Dart and a `.sql` migration with the same name is an error.

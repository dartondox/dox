---
icon: lucide/sprout
---

# Seeders

A seeder puts data in your database.
Use it for sample data in development, or for data your app needs, like a list of countries.

## Create a seeder

```bash
dox make:seeder UserSeeder
```

This makes three files:

| File | What it is |
| --- | --- |
| `db/seeders/user.seeder.dart` | the new seeder |
| `db/seeders/seeders.dart` | the list of all seeders. Dox writes it again on each `make:seeder` and `db:seed`. Do not edit it. |
| `bin/seed.dart` | the script that runs a seeder. It is made only when it is missing. |

```dart title="db/seeders/user.seeder.dart"
import 'package:dox_migration/dox_migration.dart';

import '../factories/user.factory.dart';

class UserSeeder extends Seeder {
  @override
  Future<void> run() async {
    await UserFactory().count(10).create();
  }
}
```

Use [factories](factories.md), models or the [query builder](query-builder.md) in `run()`.

## DatabaseSeeder

`dox db:seed` runs `DatabaseSeeder` by default.
Use it to call your other seeders.

```bash
dox make:seeder DatabaseSeeder
```

```dart title="db/seeders/database.seeder.dart"
import 'package:dox_migration/dox_migration.dart';

import 'post.seeder.dart';
import 'user.seeder.dart';

class DatabaseSeeder extends Seeder {
  @override
  Future<void> run() async {
    await call(<Seeder>[UserSeeder(), PostSeeder()]);
  }
}
```

`call()` runs the seeders one after another, in the list order.

## Run seeders

| Command | What it does |
| --- | --- |
| `dox db:seed` | Run `DatabaseSeeder`. |
| `dox db:seed --class=UserSeeder` | Run one seeder. |
| `dox migration:fresh --seed` | Drop all tables, run all migrations, then run `DatabaseSeeder`. |
| `dox migration:refresh --seed` | Undo all migrations, run them again, then run `DatabaseSeeder`. |
| `dox migration:run --seed` | Run new migrations, then run `DatabaseSeeder`. |

`migrate:fresh` and `migrate:refresh` are short names, so `dox migrate:fresh --seed` works too.

The database comes from `.env`, the same as the migrations:
`DATABASE_URL`, or `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD` and `DB_NAME`.

!!! warning
    `migration:fresh` drops every table of the database, also tables that no migration made.
    Do not run it on a production database.

## Transactions

A seed runs in one transaction.
When a seeder throws an error, nothing is saved, and the command exits with code 1.

On MySQL and MariaDB, `CREATE`, `ALTER` and `DROP TABLE` save right away.
A rollback can not undo them. Keep schema changes in migrations.

A very large seed can turn the transaction off:

```dart
class BigSeeder extends Seeder {
  @override
  bool get withinTransaction => false;

  @override
  Future<void> run() async {
    // ...
  }
}
```

Only the seeder you run says if there is a transaction.
For `dox db:seed` it is `DatabaseSeeder`.

## bin/seed.dart

`dox db:seed` runs `dart run bin/seed.dart`.
You can run it yourself too, for example in a deploy script:

```bash
dart run bin/seed.dart
dart run bin/seed.dart --class=UserSeeder
```

```dart title="bin/seed.dart"
import 'dart:io';

import 'package:dox_migration/dox_migration.dart';

import '../db/seeders/seeders.dart';

Future<void> main(List<String> args) async {
  exitCode = await SeederRunner(seeders: seeders).run(args);
}
```

`SeederRunner` sets up the ORM, runs the seeder and closes the ORM.
Pass `config:` to use your app's database config instead of `.env`:

```dart
import 'package:my_app/config/database.dart';

Future<void> main(List<String> args) async {
  exitCode = await SeederRunner(
    seeders: seeders,
    config: databaseConfig,
  ).run(args);
}
```

## Use in tests

A seeder is a normal class. Call `run()` after you set up the ORM:

```dart
await DatabaseSeeder().run();
```

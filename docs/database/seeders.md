---
icon: lucide/sprout
---

# Seeders

A seeder puts data in your database, like sample data for development or a list of countries your app needs.

## Writing seeders

Use the `make:seeder` command to make a seeder:

```bash
dox make:seeder UserSeeder
```

This makes `db/seeders/user.seeder.dart`. It also writes `db/seeders/seeders.dart`, the list of all seeders, and `bin/seed.dart`, the script that runs them. Do not edit the list, because Dox writes it again on each `make:seeder` and `db:seed`.

A seeder has one method, `run`. Put your code there. You can use [factories](factories.md), models or the [query builder](query-builder.md):

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

### Calling other seeders

`dox db:seed` runs `DatabaseSeeder` by default. So you use `DatabaseSeeder` to call your other seeders, with the `call` method:

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

`call` runs the seeders one after another, in the list order.

## Running seeders

Use the `db:seed` command to run `DatabaseSeeder`:

```bash
dox db:seed
```

If you want to run only one seeder, use `--class`:

```bash
dox db:seed --class=UserSeeder
```

You can also seed right after the migrations. Add `--seed` to `migration:run`, `migration:refresh` or `migration:fresh`:

```bash
dox migration:fresh --seed
```

`migration:fresh` drops every table of the database, also tables that no migration made. So do not run it on a production database.

The seeders use the same database as the migrations. See [Database settings](migration.md#database-settings).

### Transactions

A seed runs in one transaction. If a seeder throws an error, nothing is saved, and the command exits with code 1.

On MySQL and MariaDB, `CREATE`, `ALTER` and `DROP TABLE` save right away, and a rollback can not undo them. So keep schema changes in migrations.

A very large seed can turn the transaction off with `withinTransaction`. Only the seeder you run decides this. For `dox db:seed` it is `DatabaseSeeder`:

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

## Testing

A seeder is a normal class. In a test, call `run` after you set up the ORM:

```dart
await DatabaseSeeder().run();
```

## Details

### bin/seed.dart

`dox db:seed` runs `dart run bin/seed.dart`. You can run it yourself too, for example in a deploy script:

```bash
dart run bin/seed.dart
dart run bin/seed.dart --class=UserSeeder
```

`bin/seed.dart` is made only when it is missing. `SeederRunner` sets up the ORM, runs the seeder and closes the ORM:

```dart title="bin/seed.dart"
import 'dart:io';

import 'package:dox_migration/dox_migration.dart';

import '../db/seeders/seeders.dart';

Future<void> main(List<String> args) async {
  exitCode = await SeederRunner(seeders: seeders).run(args);
}
```

By default it reads the database from `.env`. Pass `config:` to use your app's database config instead:

```dart
import 'package:my_app/config/database.dart';

Future<void> main(List<String> args) async {
  exitCode = await SeederRunner(
    seeders: seeders,
    config: databaseConfig,
  ).run(args);
}
```

### Other cases

- `migrate:fresh` and `migrate:refresh` are short names, so `dox migrate:fresh --seed` works too.
- `migration:refresh --seed` undoes all migrations, runs them again, then runs `DatabaseSeeder`. `migration:run --seed` runs the new migrations, then `DatabaseSeeder`.

## See also

- [Factories](factories.md): make many rows fast.
- [Testing with a database](../guides/testing-with-database.md): use the database in tests.

---
icon: lucide/sprout
---

# Seeders

A seeder puts data in your database, like sample data for development or a list of countries your app needs.

## Writing seeders

`make:seeder` makes a seeder:

```bash
dox make:seeder UserSeeder
```

This makes `db/seeders/user.seeder.dart`. It also writes `db/seeders/seeders.dart`, the list of all seeders, and `bin/seed.dart`. Do not edit the list, because Dox writes it again.

Put your code in `run`. You can use [factories](factories.md), models or the [query builder](query-builder.md):

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

`dox db:seed` runs `DatabaseSeeder`. Use its `call` method to run your other seeders, one after another:

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

## Running seeders

`db:seed` runs `DatabaseSeeder`. `--class` runs one seeder:

```bash
dox db:seed
dox db:seed --class=UserSeeder
```

`--class` finds the seeder by its `name`, which is the class name. To seed after the migrations, add `--seed` to `migration:run`, `migration:refresh` or `migration:fresh`:

```bash
dox migration:fresh --seed
```

The seeders use the same database as the migrations. See [Database settings](migration.md#database-settings).

### Transactions

A seed runs in one transaction. If a seeder throws, nothing is saved, and the command exits with code 1. For a very large seed, turn the transaction off:

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

Only the seeder you run decides this. For `dox db:seed`, it is `DatabaseSeeder`.

### The seed script

`dox db:seed` runs `bin/seed.dart`. `SeederRunner` sets up the ORM, runs the seeder and closes the ORM. Pass `config` to use the database config of the app in place of `.env`:

```dart title="bin/seed.dart"
import 'dart:io';

import 'package:dox_migration/dox_migration.dart';
import 'package:my_app/config/database.dart';

import '../db/seeders/seeders.dart';

Future<void> main(List<String> args) async {
  exitCode = await SeederRunner(
    seeders: seeders,
    config: databaseConfig,
  ).run(args);
}
```

You can run it yourself, like `dart run bin/seed.dart --class=UserSeeder`. From code, `seed` runs one seeder by name:

```dart
await SeederRunner(seeders: seeders).seed('UserSeeder');
```

## Testing

In a test, set up the ORM, then call `run`:

```dart
await DatabaseSeeder().run();
```

## Next steps

- [Factories](factories.md): make many rows fast.
- [Migration](migration.md): make the tables first.
- [Testing with a database](../guides/testing-with-database.md): use the database in tests.

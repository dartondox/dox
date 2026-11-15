---
icon: lucide/database
---

# Step 2: Model and migration

In this step you make the `posts` table with a migration, and a `Post` model to read and write it.

## 1. Make the model and the migration

Stop `dox s` first with `Ctrl+C`. You need to do this because `dox s` restarts the server when a new file appears, and the server runs new migrations at start. So it would run the new migration before you add the columns.

Now make the model and its migration:

```bash
dox make:model Post -m
```

This makes two files and updates one:

| File | What it is |
| --- | --- |
| `lib/app/models/post/post.model.dart` | the model (new) |
| `db/migration/<date>_create_posts_table.dart` | the migration (new) |
| `db/migration/migrations.dart` | the list of all Dart migrations. Dox writes it. Do not edit it. |

The `dox migration:*` commands run `bin/migrate.dart`, which the template already has.

## 2. Add the columns to the migration

A new migration has no columns yet. Open the new file in `db/migration` and add `title` and `body`:

```dart title="db/migration/2026_10_22_205345_create_posts_table.dart"
// ignore_for_file: file_names
import 'package:dox_migration/dox_migration.dart';

class CreatePostsTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('posts', (Table table) {
      table.id();
      table.string('title');
      table.text('body');
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('posts');
  }
}
```

- `table.id()` makes an auto increment primary key.
- `table.timestamps()` makes `created_at` and `updated_at`. The model fills them for you.

## 3. Add the fields to the model

The model needs one field for each column you added:

```dart title="lib/app/models/post/post.model.dart"
import 'package:dox_orm/dox_orm.dart';

part 'post.model.g.dart';

@DoxModel(table: 'posts')
class Post extends PostGenerator {
  @override
  List<String> get hidden => <String>[];

  @Column()
  String? title;

  @Column()
  String? body;
}
```

Every column field is nullable, because a new `Post()` has no values yet. You do not declare `id`, `createdAt` and `updatedAt`, because they come from `PostGenerator`.

## 4. See how migrations run

You do not need to change anything here. The template's `bin/server.dart` already runs the migrations before the server starts:

```dart title="bin/server.dart"
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

This also works in the native binary of [step 7](07-build-and-deploy.md).

## 5. Run the migration and the generator

Run the new migration now:

```bash
dox migration:run
```

```text
Migrating: 2026_10_22_205345_create_posts_table
Migrated: 2026_10_22_205345_create_posts_table
```

!!! tip "The migration ran too early?"
    If `dox s` was still running, the `posts` table may already exist without `title` and `body`. Run `dox migration:rollback`, then `dox migration:run` again.

The model also needs its generated file `post.model.g.dart`. `dox s` makes it while it runs. If `dox s` is not running, run the generator once:

```bash
dart run build_runner build
```

## Check it

See which migrations ran:

```bash
dox migration:status
```

You should see:

```text
Migration                                 Batch  Status
2023_07_16_131937700_create_users_table   1      Ran
2026_10_25_000000000_create_queue_tables  1      Ran
2026_10_22_205345_create_posts_table      2      Ran
```

The first two come with the template. The server ran them at the first start in step 1.

Now start the server again with `dox s`.

## Next

[Step 3: Routes and controller](03-routes-and-controller.md)

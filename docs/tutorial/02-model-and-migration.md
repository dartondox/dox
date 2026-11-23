---
icon: lucide/database
---

# Step 2: Model and migration

In this step you make the posts table with a migration, and a `Post` model to read and write it.

## 1. Make the model and the migration

Stop `dox s` first with Ctrl+C. The server runs new migrations when it starts, so it would run the migration before you add the columns.

Make the model and its migration:

```bash
dox make:model Post -m
```

This makes two files and updates one:

| File | What it is |
| --- | --- |
| `lib/app/models/post/post.model.dart` | the model (new) |
| `db/migration/<date>_create_posts_table.dart` | the migration (new) |
| `db/migration/migrations.dart` | the list of all Dart migrations. Dox writes it. Do not edit it. |

## 2. Add the columns to the migration

Open the new file in `db/migration` and add a title and a body:

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

`table.id()` makes an auto increment primary key. `table.timestamps()` makes the created_at and updated_at columns, and the model fills them.

## 3. Add the fields to the model

Add one field for each new column:

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

Each field is nullable, because a new `Post()` has no values. The id and the timestamps come from `PostGenerator`.

## 4. See how migrations run

You do not change anything here. The template's `bin/server.dart` runs the migrations before the server starts:

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

Run the new migration:

```bash
dox migration:run
```

```text
Migrating: 2026_10_22_205345_create_posts_table
Migrated: 2026_10_22_205345_create_posts_table
```

If `dox s` was still on, the table can exist without the new columns. Then run `dox migration:rollback` and `dox migration:run` again.

The model also needs its generated file. `dox s` makes it, so if the server is off, run the generator one time:

```bash
dart run build_runner build
```

## Check it

See which migrations ran:

```bash
dox migration:status
```

You see:

```text
Migration                                 Batch  Status
2023_07_16_131937700_create_users_table   1      Ran
2026_10_25_000000000_create_queue_tables  1      Ran
2026_10_22_205345_create_posts_table      2      Ran
```

The first two come with the template. The server ran them in step 1.

Start the server again with `dox s`.

## Next steps

- [Step 3: Routes and controller](03-routes-and-controller.md): add the post routes.

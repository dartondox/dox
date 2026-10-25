# Step 2: Model and migration

This step makes the `posts` table with a Dart migration and a `Post` model for it.

## 1. Make the model and the migration

```bash
dox create:model Post -m
```

This makes two files and updates one:

| File | What it is |
| --- | --- |
| `lib/app/models/post/post.model.dart` | the model (new) |
| `db/migration/<date>_create_posts_table.dart` | the migration (new) |
| `db/migration/migrations.dart` | the list of all Dart migrations. Dox writes it. Do not edit it. |

The template already has `bin/migrate.dart`. The `dox migration:*` commands run it.

## 2. Add the columns to the migration

Open the new file in `db/migration`. Add `title` and `body`:

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

- `table.id()` makes an auto increment primary key on every database.
- `table.timestamps()` makes `created_at` and `updated_at`. The model fills them.

## 3. Add the fields to the model

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

Every column field is nullable. A new `Post()` has no values yet.
`id`, `createdAt` and `updatedAt` come from `PostGenerator`. You do not declare them.

## 4. Run the migrations on server start

Nothing to change here. The template's `bin/server.dart` already runs the migrations before the server starts:

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

```bash
dox migration:run
```

```text
Migrating: 2026_10_22_205345_create_posts_table
Migrated: 2026_10_22_205345_create_posts_table
```

The model needs its generated file `post.model.g.dart`.
`dox s` makes it while it runs. If `dox s` is not running, run the generator once:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Check it

```bash
dox migration:status
```

```text
Migration                             Batch  Status
2026_10_22_205345_create_posts_table  1      Ran
```

## Next

[Step 3: Routes and controller](03-routes-and-controller.md)

# dox_orm example

A model, a migration and the common queries. The full guide is on
[dartondox.dev](https://dartondox.dev/latest/database/).

## 1. Config

```dart title="lib/config/database.dart"
import 'package:dox_orm/dox_orm.dart';

DatabaseConfig databaseConfig = DatabaseConfig(
  connection: 'sqlite',
  connections: <String, ConnectionConfig>{
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: 'db/app.sqlite',
    ),
  },
);
```

## 2. Migration

```dart title="db/migration/2026_01_01_000000_create_posts_table.dart"
import 'package:dox_migration/dox_migration.dart';

class CreatePostsTable extends Migration {
  @override
  Future<void> up(Schema schema) async {
    await schema.create('posts', (Table table) {
      table.id();
      table.string('title');
      table.text('body');
      table.string('status').defaultTo('draft');
      table.timestamps();
    });
  }

  @override
  Future<void> down(Schema schema) async {
    await schema.dropIfExists('posts');
  }
}
```

## 3. Model

```dart title="lib/app/models/post/post.model.dart"
import 'package:dox_orm/dox_orm.dart';

part 'post.model.g.dart';

@DoxModel(table: 'posts')
class Post extends PostGenerator {
  @Column()
  String? title;

  @Column()
  String? body;

  @Column()
  String? status;
}
```

Run `dart run build_runner build` to make `post.model.g.dart`.

## 4. Queries

```dart
// create
Post post = Post()
  ..title = 'Hello'
  ..body = 'First post';
await post.save();

// read
Post? one = await Post().find(post.id);
List<Post> drafts = await Post()
    .where('status', 'draft')
    .orderBy('id', 'desc')
    .limit(10)
    .get();

// update
one?.title = 'Hello again';
await one?.save();

// delete
await one?.delete();
```

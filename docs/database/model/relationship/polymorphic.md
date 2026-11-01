---
icon: lucide/share-2
---

# Polymorphic

Use a polymorphic relation when one model can belong to more than one other model.

For example, a comment can belong to a photo or to a video.
The `comment` table does not have a `photo_id` and a `video_id`.
It has two columns:

- `commentable_id`: the id of the photo or the video.
- `commentable_type`: the type, like `photo` or `video`.

`commentable` is the morph name. You pick it.

## Tables

| Table | Columns |
|---|---|
| `photo` | `id`, `title` |
| `video` | `id`, `title` |
| `comment` | `id`, `body`, `commentable_id`, `commentable_type` |

`morphs()` adds both columns and an index:

```dart
await schema.create('comment', (Table table) {
  table.id();
  table.string('body');
  table.morphs('commentable');
  table.timestamps();
});
```

## The morph map

The morph map gives each model a type name.
The type name is the value in the `commentable_type` column.

Set it in the `setup()` of a [provider](../../../digging-deeper/providers.md).
Dox runs providers in every isolate, before the first request.
The map is kept per isolate, so setting it only in `main()` is not enough.
Then the other isolates store the class name, and `@MorphTo` throws there.

```dart
class MorphMapProvider extends DoxProvider {
  @override
  void setup() {
    Model.morphMap(<String, Model<dynamic> Function()>{
      'photo': Photo.new,
      'video': Video.new,
    });
  }
}
```

A queue worker or a CLI command that reads these relations must call it too.

- `@MorphTo` needs it. It reads the type and makes the model from the map.
- Without a map, `@MorphMany` and `@MorphOne` store the class name, like `Photo`.
- Use a morph map in production. The class name changes when you rename the class, or when you build with `--obfuscate`. Then the old rows do not match.
- Do not change a type name later. The rows in the table keep the old name.
- `Model.morphMap(map, merge: false)` removes the names you set before.

Two helpers read the map:

```dart
String type = Model.morphTypeOf(Photo()); // 'photo'
Model<dynamic> model = Model.morphModel('video'); // a new Video()
```

## Define it

### `@MorphMany`

A photo has many comments.
The second argument is the morph name.

```dart title="lib/app/models/photo/photo.model.dart"
import 'package:dox_orm/dox_orm.dart';

import '../comment/comment.model.dart';

part 'photo.model.g.dart';

@DoxModel()
class Photo extends PhotoGenerator {
  @Column()
  String? title;

  @MorphMany(Comment, 'commentable')
  List<Comment> comments = <Comment>[];
}
```

### `@MorphOne`

A photo has one cover image.
It works like `@MorphMany`, but the field is one model.

```dart
@MorphOne(Image, 'imageable')
Image? cover;
```

When there are many rows, it keeps the last row the query returns.
Add an `orderBy` in `onQuery` to pick the row, like with [HasOne](has-one.md).

### `@MorphTo`

A comment belongs to a photo or a video.
The field type is `Model<dynamic>?`.
The morph name is the field name in snake_case: `commentable`.
The `commentable_id` and `commentable_type` columns must be `@Column` fields, or the relation is always `null`.

```dart title="lib/app/models/comment/comment.model.dart"
import 'package:dox_orm/dox_orm.dart';

part 'comment.model.g.dart';

@DoxModel()
class Comment extends CommentGenerator {
  @Column()
  String? body;

  @Column()
  int? commentableId;

  @Column()
  String? commentableType;

  @MorphTo()
  Model<dynamic>? commentable;
}
```

Run `dart run build_runner build` after you add a relationship.

## Save a row

There is no `associate()`. Set the two columns yourself.
Use `Model.morphTypeOf()` for the type, so it is the same as the morph map.

```dart
Comment comment = Comment()
  ..body = 'Nice'
  ..commentableId = photo.id
  ..commentableType = Model.morphTypeOf(photo);
await comment.save();
```

## Load it

Load it like the other relations: `preload`, `$getRelation`, `related` or `eager`.

```dart
Photo? photo = await Photo().preload('comments').find(1);
print(photo?.comments.length);

List<Comment> comments = await Comment().preload('commentable').get();
for (Comment c in comments) {
  if (c.commentable is Photo) {
    print((c.commentable as Photo).title);
  }
}
```

- `@MorphMany` and `@MorphOne` run one query for all models.
  It has `where commentable_type = 'photo'`.
- `@MorphTo` runs one query for each type in the list.
  A comment with a type that is not in the morph map throws a `StateError`.
  A comment with no type gets `null`.
- `related<Photo>('commentable')` on one comment gives the query of its photo.

## Filter by it

`whereHas()`, `whereDoesntHave()` and `withCount()` work with `@MorphMany` and `@MorphOne`.

```dart
List<Photo> photos = await Photo().whereHas('comments').get();
List<Video> videos = await Video().withCount('comments').get();
```

They do not work with `@MorphTo`. It throws an `UnsupportedError`.

## Options

### `@MorphMany` and `@MorphOne`

The examples are for `@MorphMany(Comment, 'commentable')` in the `Photo` model.

| Option | Default | Example value | What it is |
|---|---|---|---|
| `name` (2nd argument) | | `commentable` | The morph name. |
| `typeColumn` | `{name}_type` | `commentable_type` | The type column in `comment`. |
| `idColumn` | `{name}_id` | `commentable_id` | The id column in `comment`. |
| `localKey` | the primary key of this model | `id` | The column in `photo` that `idColumn` points to. |
| `onQuery` | none | | A static function that changes the query. |
| `eager` | `false` | | Load the relation on every query. |

### `@MorphTo`

| Option | Default | Example value | What it is |
|---|---|---|---|
| `name` | the field name in snake_case | `commentable` | The morph name. |
| `typeColumn` | `{name}_type` | `commentable_type` | The type column in this table. |
| `idColumn` | `{name}_id` | `commentable_id` | The id column in this table. |
| `ownerKey` | the primary key of the related model | `id` | The column in the related table that `idColumn` points to. |
| `onQuery` | none | | A static function that changes the query of each type. It runs for every type, so it takes and returns `Model<dynamic>`. |
| `eager` | `false` | | Load the relation on every query. |

## In JSON

- A relation with `eager: true` is always in `toJson()`.
- A relation loaded with `preload` is in `toJson()` of that query.
- The JSON key is the field name in snake_case: `comments`, `commentable`.

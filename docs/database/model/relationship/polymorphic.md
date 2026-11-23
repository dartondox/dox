---
icon: lucide/share-2
---

# Polymorphic

Use a polymorphic relation when one model can belong to more than one other model.

For example, a comment can belong to a photo or to a video. The `comment` table keeps the id in `commentable_id` and the type, like `photo`, in `commentable_type`. `commentable` is the **morph name**, and you pick it.

## Setup

### Tables

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
});
```

### The morph map

The **morph map** gives each model the type name that goes in the type column. Set it in the `setup()` of a [provider](../../../digging-deeper/providers.md), so it runs in every isolate:

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

`@MorphTo` throws without the map. Without it, the other relations store the class name, which changes when you rename the class or build with `--obfuscate`. Do not change a type name later, because then the old rows do not match.

A queue worker or a CLI command that reads these relations must set the map too. `merge: false` removes the names you set before.

### Defining the relation

A photo has many comments. Use `@MorphMany`, with the morph name as the second argument:

```dart title="lib/app/models/photo/photo.model.dart"
@DoxModel()
class Photo extends PhotoGenerator {
  @MorphMany(Comment, 'commentable')
  List<Comment> comments = <Comment>[];
}
```

For one row, use `@MorphOne`. When there are many rows, it keeps the last row of the query:

```dart
@MorphOne(Image, 'imageable')
Image? cover;
```

A comment belongs to a photo or a video. Use `@MorphTo` on a `Model<dynamic>?` field. The id and type columns must be `@Column` fields:

```dart title="lib/app/models/comment/comment.model.dart"
@DoxModel()
class Comment extends CommentGenerator {
  @Column()
  int? commentableId;

  @Column()
  String? commentableType;

  @MorphTo()
  Model<dynamic>? commentable;
}
```

Run `dart run build_runner build` after you add a relation.

### Options

The examples are for `@MorphMany(Comment, 'commentable')` in the `Photo` model. `@MorphOne` has the same options:

| Option | Default | What it is |
|---|---|---|
| `name` (2nd argument) | required | The morph name, like `commentable`. |
| `typeColumn` | `{name}_type` | The type column in `comment`. |
| `idColumn` | `{name}_id` | The id column in `comment`. |
| `localKey` | the primary key of this model | The column in `photo` that `idColumn` points to. |
| `onQuery` | none | A static function that changes the query. |
| `eager` | `false` | Load the relation on every query. |

The options of `@MorphTo`:

| Option | Default | What it is |
|---|---|---|
| `name` | the field name in snake_case | The morph name. |
| `typeColumn` | `{name}_type` | The type column in this table. |
| `idColumn` | `{name}_id` | The id column in this table. |
| `ownerKey` | the primary key of the related model | The column in the related table that `idColumn` points to. |
| `onQuery` | none | A static function that changes the query of each type. |
| `eager` | `false` | Load the relation on every query. |

## Loading the relation

The relation is not loaded by default. Use the field name, like `'comments'` or `'commentable'`, as the relation name.

### Preloading

`preload()` loads the relation for all models of a query. A `@MorphTo` runs one query for each type:

```dart
List<Comment> comments = await Comment().preload('commentable').get();
for (Comment c in comments) {
  if (c.commentable is Photo) print((c.commentable as Photo).title);
}
```

A type that is not in the morph map throws a `StateError`. No type, or an empty type, gives null.

### Loading on a model you have

`$getRelation()` loads the relation into the field:

```dart
await photo.$getRelation('comments');
```

### Querying the relation

`related()` gives a query for the related rows. It does not set the field:

```dart
List<Comment> recent = await photo
        .related<Comment>('comments')
        ?.orderBy('id', 'desc')
        .get() ??
    <Comment>[];
```

### Always loading the relation

Set `eager: true` to load the relation on every query of the model:

```dart
@MorphMany(Comment, 'commentable', eager: true)
List<Comment> comments = <Comment>[];
```

## Saving related models

`createRelated()`, `saveRelated()` and `saveManyRelated()` work with `@MorphMany` and `@MorphOne`. They set the id and the type column:

```dart
await photo.createRelated<Comment>('comments',
    <String, dynamic>{'body': 'Nice'});
```

A `@MorphTo` has no `associate()`. Set the two columns yourself, and get the type with `Model.morphTypeOf()`:

```dart
Comment comment = Comment()
  ..body = 'Nice'
  ..commentableId = photo.id
  ..commentableType = Model.morphTypeOf(photo);
await comment.save();
```

`Model.morphModel('video')` gives a new model of a type name.

## Filtering by the relation

`whereHas()`, `whereDoesntHave()` and `withCount()` work with `@MorphMany` and `@MorphOne`. A `@MorphTo` throws an `UnsupportedError`:

```dart
List<Photo> photos = await Photo().whereHas('comments').get();
List<Video> videos = await Video().withCount('comments').get();
```

See [Query by relations](../relation-queries.md).

## Changing the relation query

Give `onQuery` a static function of the model. For `@MorphTo`, it runs for the query of each type, so it takes and returns `Model<dynamic>`:

```dart
@MorphTo(onQuery: notHidden)
Model<dynamic>? commentable;

static Model<dynamic> notHidden(Model<dynamic> q) {
  q.whereNull('hidden_at');
  return q;
}
```

## Next steps

- [HasMany](has-many.md): a relation to one model.
- [Providers](../../../digging-deeper/providers.md): set the morph map.

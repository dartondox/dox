# Model

A model is a Dart class for one database table, used to read, create, change and delete its rows.

Each object of the model is one row. A model also has all the [query builder](../query-builder.md) methods, so you can query the table through it.

## Setup

Use `make:model` to make a new model. The `-m` option also makes a migration for the table:

```bash
dox make:model Blog      # only the model
dox make:model Blog -m   # the model and a migration for the table blogs
dox make:model Blog -a   # also a migration, factory, seeder, controller
```

This makes `lib/app/models/blog/blog.model.dart`. For the other options, see the [CLI reference](../../reference/cli.md#dox-makemodel).

A model uses a generated class, so run the generator after you make or change a model. Use `watch` in place of `build` to run it on each save:

```bash
dart run build_runner build
```

### Model options

All options go in `@DoxModel(...)`:

| Option | Default | What it does |
|---|---|---|
| `table` | class name in snake_case | The table name. |
| `primaryKey` | `'id'` | The primary key column. |
| `primaryKeyType` | `int` | The Dart type of the primary key, like `String` for a UUID. |
| `createdAt` | `'created_at'` | The column that keeps the create time. null turns it off. |
| `updatedAt` | `'updated_at'` | The column that keeps the last update time. null turns it off. |
| `timestamps` | `true` | false turns off `createdAt` and `updatedAt`. |
| `softDelete` | `false` | `delete()` sets `deleted_at` and keeps the row. |

## Defining models

A model is a class with `@DoxModel()`. Each `@Column()` field is one column of the table:

```dart title="lib/app/models/blog/blog.model.dart"
import 'package:dox_orm/dox_orm.dart';

part 'blog.model.g.dart'; // (1)!

@DoxModel() // (2)!
class Blog extends BlogGenerator { // (3)!
  @Column() // (4)!
  String? title;

  @Column(name: 'body') // (5)!
  String? description;

  @Column(name: 'user_id')
  int? userId;
}
```

1.  `build_runner` writes this file. It holds the generated `BlogGenerator` class.
2.  Marks the class as a model. See [Model options](#model-options).
3.  The generated class gives the model `id`, `createdAt` and `updatedAt`, and the query builder methods.
4.  The column name is the field name in snake_case.
5.  Use `name` when the column name is not the snake_case of the field.

Make every column field nullable, because a new model has no values yet.

### Table names

The default table name is the class name in snake_case: `BlogPost` uses `blog_post`. Set `table` for another name:

```dart
@DoxModel(table: 'blogs')
class Blog extends BlogGenerator {}
```

`dox make:model Blog` sets `table: 'blogs'` for you. With the [`pluralTableNames` flag](../index.md#orm-flags), the default name is plural.

### Primary keys

Set `primaryKey` for a key with another name, and `primaryKeyType` for a key that is not an integer:

```dart
@DoxModel(primaryKey: 'uuid', primaryKeyType: String)
class Device extends DeviceGenerator {}
```

The field name is the key in camelCase. `save()` inserts a new model, also when you set the key yourself.

### Timestamps

`save()` sets `created_at` and `updated_at` to the current UTC time. Set other column names, or turn them off:

```dart
@DoxModel(createdAt: 'created', updatedAt: 'modified')
class Blog extends BlogGenerator {}

@DoxModel(timestamps: false)
class Setting extends SettingGenerator {}
```

### Column types

The field type tells Dox how to read the value:

| Field type | Column |
|---|---|
| `String?` | text, varchar |
| `int?` | integer types |
| `double?` | float, double. MySQL also gives decimal as a double. Postgres gives numeric as a string. |
| `bool?` | boolean, or a number like tinyint (0 is false) |
| `DateTime?` | date, datetime, timestamp |
| `Map<String, dynamic>?` or `List<dynamic>?` | JSON |
| an enum, like `Status?` | text with the enum name |

For other types, use a [cast](casts.md).

### Changing values on save and read

`beforeSave` and `beforeGet` take a static function of the model. The function gets a map of the values and returns the new value:

```dart
@Column(beforeSave: makeSlug)
String? slug;

@Column(beforeGet: readStatus)
String? status;

static String? makeSlug(Map<String, dynamic> map) {
  return map['title']?.toString().toLowerCase().replaceAll(' ', '-');
}

static String? readStatus(Map<String, dynamic> map) {
  return map['status'] as String? ?? 'draft';
}
```

`beforeSave` gets the model values by column name. `beforeGet` gets the row from the database.

### Using another connection

Use a named connection for the query, and for the save and delete of its models:

```dart
Blog blog = Blog()..withConnection('mysql');
await blog.save();
```

## Retrieving models

Use the [query builder](../query-builder.md) methods to read rows:

```dart
Blog? found = await Blog().find(1);
List<Blog> drafts = await Blog().where('status', 'draft').get();
```

### Starting a new query

A model object keeps the parts of its query. `query()` gives a new, empty model to start another query:

```dart
Blog blog = Blog();
List<Blog> active = await blog.where('status', 'active').get();
List<Blog> deleted = await blog.query().where('status', 'deleted').get();
```

### Refreshing models

`refresh()` reads the row again into this model, with its relations. `fresh()` gives a new model and keeps this one as it is:

```dart
await blog.refresh();
Blog? now = await blog.fresh(); // null when the row is gone
```

Both read the row by its primary key. They also find a soft deleted row.

### Reloading relations

`reload()` loads the relations of the model again, for example after a save:

```dart
await blog.save();
await blog.reload();
```

## Inserting and updating models

### Inserts

Make a new model, set its fields and call `save()`:

```dart
Blog blog = Blog();
blog.title = 'My first blog';
await blog.save();
print(blog.id); // the new id
```

Null fields are not sent, so the database default is used.

### Updates

`save()` on a model from the table updates it. It sends only the fields that changed:

```dart
Blog? found = await Blog().find(1);
found?.title = 'New title';
await found?.save();
```

To clear a column, set the field to null and save. A map or list field is always sent, because it can change in place.

`save()` returns false when a [model event](events.md) cancels it. `saveQuietly()` saves with no events.

### Checking if a row exists

`exists` is true when the model is in the table. `wasRecentlyCreated` is true after a save inserted the row:

```dart
User user = await User().firstOrCreate(<String, dynamic>{'email': email});
if (user.wasRecentlyCreated) await sendWelcomeMail(user);
```

### Creating from a map

`create()` makes a new row from a map and returns the model. The model needs `fillable`, see [Mass assignment](#mass-assignment):

```dart
Blog created = await Blog().create(<String, dynamic>{
  'title': 'My first blog',
  'status': 'draft',
});
```

It works like `save()` on a new model, with the events. A null key is not sent, unless the [`createWritesNull` flag](../index.md#orm-flags) is on. `insert()` on a model does the same as `create()`.

### Updating from a map

`update()` on a model from the table changes only that row and sets `updated_at`. It fires no model events:

```dart
await blog.update(<String, dynamic>{'status': 'live'});
```

### Mass assignment

`create()`, `insert()`, `update()`, `upsert()` and the find or create methods take their keys from a map. So a model is guarded by default. List the keys that may come from a map:

```dart
@DoxModel()
class User extends UserGenerator {
  // only these keys are taken from a map
  @override
  List<String> get fillable => <String>['name', 'email'];

  // or: every key but these is taken from a map
  @override
  List<String> get guarded => <String>['is_admin'];
}
```

With `fillable`, other keys are dropped. A model with no `fillable` and the default `guarded` throws a `MassAssignmentException` for a map with keys. Fields you set in code are always saved.

To take every key, set `guarded` to an empty list. This is not safe with user input:

```dart
@override
List<String> get guarded => const <String>[];
```

#### Skip the fillable check

These methods ignore `fillable` and `guarded`. Never pass user input, like `req.body`, to them:

```dart
await User().forceCreate(
    <String, dynamic>{'name': 'Ann', 'is_admin': true});
await User().where('id', 1)
    .forceUpdate(<String, dynamic>{'is_admin': true});
await user.forceFill(<String, dynamic>{'is_admin': true}).save();
```

`forceFill()` sets the fields and does not save. Model events that fire inside `forceCreate()` and `forceUpdate()` also skip the check.

`Model.unguarded()` turns the check off for everything inside the callback. Await all work inside it, because work that ends later also runs with the check off:

```dart
await Model.unguarded(() async {
  await User().create(<String, dynamic>{'name': 'Bob', 'is_admin': true});
});
```

`Model.isUnguarded` is true inside the callback.

### Find or create

These methods find a row by the first map. When there is no row, they use both maps:

```dart
User user = await User().firstOrCreate(
  <String, dynamic>{'email': 'ann@example.com'},
  <String, dynamic>{'name': 'Ann'},
);

User other = await User().firstOrNew(
    <String, dynamic>{'email': 'bob@example.com'});

User updated = await User().updateOrCreate(
  <String, dynamic>{'email': 'ann@example.com'},
  <String, dynamic>{'name': 'Ann Lee'},
);
```

`firstOrNew()` does not save the new model. See the [query builder](../query-builder.md#finding-or-creating-a-row).

### Incrementing and decrementing

Add to or take from a number column in one query. The field gets the new value too:

```dart
await blog.increment('views');      // views + 1
await blog.increment('views', 5);   // views + 5
await blog.decrement('views');      // views - 1
await blog.increment('views', 1, <String, dynamic>{'status': 'hot'});
```

The third argument sets other columns. They fire no model events and do not set `updated_at`, unless the [`incrementFiresEvents` flag](../index.md#orm-flags) is on.

### Touch and replicate

`touch()` sets `updated_at`, or the column you give, to now. It fires the save events. `touchQuietly()` fires none:

```dart
await blog.touch();               // updated_at = now
await blog.touch('published_at'); // published_at = now
```

`replicate()` makes an unsaved copy with no primary key and no timestamps. List the columns to leave out:

```dart
Blog copy = blog.replicate(<String>['slug'])..title = 'Copy';
await copy.save();
```

Relations are not copied. The copy of a soft deleted model is soft deleted too.

### Checking changed columns

These methods tell you what changed before or after a save. The names are column names, like `user_id`:

```dart
blog.title = 'New title';

blog.isDirty();             // true
blog.isDirty('title');      // true
blog.isClean('body');       // true
blog.getDirty();            // {title: New title}
blog.getOriginal('title');  // the old title

await blog.save();
blog.wasChanged('title');   // true
blog.getChanges();          // {title: New title, updated_at: ...}
```

`isDirty()`, `isClean()` and `wasChanged()` also take a list of names.

## Deleting models

`delete()` deletes the row of the model. It returns 1, or 0 when the row was not there or a [model event](events.md) cancelled it:

```dart
int count = await blog.delete();
```

A model with no primary key value throws a `StateError`, so `Blog().delete()` can not delete every row. To delete the rows of a query, add a `where`. A [global scope](scopes.md#global-scopes) counts as a `where`. See [writing every row](../query-builder.md#writing-every-row).

### Soft deleting

A **soft delete** keeps the row and sets its `deleted_at`. Turn it on with `softDelete`:

```dart
@DoxModel(softDelete: true)
class Blog extends BlogGenerator {}
```

The table needs a nullable `deleted_at` column. In a migration, add `table.softDeletes();`. Queries then leave out soft deleted rows.

### Reading soft deleted rows

`withTrash()` also gets the soft deleted rows. `onlyTrashed()` gets only them:

```dart
List<Blog> all = await Blog().withTrash().get();
List<Blog> trashed = await Blog().onlyTrashed().get();
```

### Restoring soft deleted models

`trashed()` tells you if a model is soft deleted. `restore()` brings it back:

```dart
Blog? blog = await Blog().withTrash().find(1);
if (blog!.trashed()) await blog.restore();
```

### Deleting for good

`forceDelete()` deletes the row, also on a soft delete model:

```dart
await blog.forceDelete();
```

## Converting to a map or JSON

`toMap()` gives all columns and computed values. `toJson()` gives the same without hidden fields:

```dart
Map<String, dynamic> map = blog.toMap();
Map<String, dynamic> json = blog.toJson();
Map<String, dynamic> row = blog.toMap(original: true); // the raw row
```

`jsonEncode(blog)` uses `toJson()`, so a controller can return a model or a list of models.

### Hide fields

Put fields like a password in `hidden`, and `toJson()` leaves them out. Use the column names:

```dart
@override
List<String> get hidden => <String>['password', 'remember_token'];
```

To keep only some fields, list them in `visibleFields`:

```dart
@override
List<String> get visibleFields => const <String>['id', 'name'];
```

For one model or a list of models, use `makeHidden()` and `makeVisible()`:

```dart
return user.makeVisible(<String>['email']).toJson();
return users.makeHidden(<String>['phone']);
```

### Computed values

A **computed value** is a getter in the JSON that is not a column. Add `@Computed()`, then run the generator:

```dart
@Computed() // json key: full_name
String get fullName => '$firstName $lastName';

@Computed(name: 'initials') // custom json key
String get shortName => '${firstName?[0]}${lastName?[0]}';
```

The getter runs each time `toJson()` or `toMap()` runs, so keep it fast. `hidden` hides it by its json key.

## Relationships

A model can load related models. See [HasOne](relationship/has-one.md), [HasMany](relationship/has-many.md), [BelongsTo](relationship/belongs-to.md), [ManyToMany](relationship/many-to-many.md), [HasManyThrough](relationship/through.md) and [Polymorphic](relationship/polymorphic.md).

### Preloading relations

`preload()` loads a relation for all rows of a query. A dot path also loads the relations of the loaded rows:

```dart
Blog? blog = await Blog().preload('comments').find(1);
List<User> users = await User().preload('posts.comments').get();
```

### Filtering a preload

Give a callback to load only some related rows. With a dot path, it is for the last relation:

```dart
await User().preload('posts', (QueryBuilder<dynamic> q) {
  q.where('published', true);
}).get();
```

### Loading a relation on a model

`$getRelation()` loads a relation into its field. `related()` gives a query for the related rows:

```dart
await blog.$getRelation('comments');
List<Comment> recent = await blog
        .related<Comment>('comments')
        ?.orderBy('id', 'desc')
        .get() ??
    <Comment>[];
```

### Saving through a relation

These methods save a related model and set the foreign key. They work with `@HasMany`, `@HasOne`, `@MorphMany` and `@MorphOne`:

```dart
Comment c = await blog.createRelated<Comment>('comments',
    <String, dynamic>{'body': 'hi'});
await blog.saveRelated('comments', Comment()..body = 'hi');
await blog.saveManyRelated('comments', <Comment>[c1, c2]);
```

`createRelated()` uses `create()`, but the foreign key does not need to be in `fillable`. For a `@BelongsTo`, use `associate()` and `dissociate()`. See [BelongsTo](relationship/belongs-to.md#saving-related-models).

## Debugging queries

`debug(true)` prints the SQL of the model in the terminal:

```dart
Blog blog = Blog()..debug(true);
blog.title = 'John Wick';
await blog.save();
```

## Methods on other pages

| Methods | Page |
|---|---|
| `Model.observe()`, `Model.forgetObservers()`, `Model.withoutEvents()` | [Model events](events.md) |
| `withCount()`, `withSum()`, `withAvg()`, `withMin()`, `withMax()`, `withExists()`, `countOf()`, `aggregate()` | [Counting relations](counting-relations.md) |
| `whereHas()`, `orWhereHas()`, `whereDoesntHave()`, `orWhereDoesntHave()`, `has()` | [Query by relations](relation-queries.md) |
| `withoutGlobalScope()`, `withoutGlobalScopes()` | [Query scopes](scopes.md) |
| `associate()`, `dissociate()` | [BelongsTo](relationship/belongs-to.md) |
| `attach()`, `detach()`, `sync()`, `syncWithoutDetaching()`, `toggle()`, `updateExistingPivot()`, `pivot` | [ManyToMany](relationship/many-to-many.md) |
| `Model.morphMap()`, `Model.morphTypeOf()`, `Model.morphModel()` | [Polymorphic](relationship/polymorphic.md) |

## Next steps

- [HasMany](relationship/has-many.md): connect one model to many.
- [Query scopes](scopes.md): keep a query you use often in the model.
- [Model events](events.md): run code when a model is saved or deleted.
- [Factories](../factories.md): make test rows.

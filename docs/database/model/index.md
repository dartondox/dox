# Model

## Create

```bash
dox create:model Blog      # only the model
dox create:model Blog -m   # the model and its migration (table `blogs`)
```

!!! info
    This will create a blog model inside `lib/models` folder.


!!! warning
    Please run `dart run build_runner build` after new model is created. Alternatively can also run build_runner watch `dart run build_runner watch` to update changes to generator file


=== "Sample Model"

```dart
import 'package:dox_orm/dox_orm.dart';
part 'blog.model.g.dart';

@DoxModel()
class Blog extends BlogGenerator {
  @Column()
  String? title;
  
  @Column(name: 'title', beforeSave: makeSlug)
  String? slug;

  @Column()
  String? status;

  @Column(name: 'body')
  String? description;

  @Column(name: 'created_at')
  DateTime? createdAt;

  @Column(name: 'updated_at')
  DateTime? updatedAt;

  static makeSlug(Map<String, dynamic> map) {
    return Slugify().slugify(map['title']);
  }
}
```

## Model options

### `table`

```dart
@DoxModel(table: 'blogs')
```

!!! info
    Dox adheres to singular table naming conventions, but you can still employ custom table names in your model.

### `primaryKey`

```dart
@DoxModel(primaryKey: 'uid')
```

### `createdAt` / `updatedAt`

```dart
@DoxModel(createdAt: 'created_at', updatedAt: 'updated_at')
```

!!! info
    Dox typically utilizes the columns named `created_at` and `updated_at` as timestamp columns by default. However, if you wish to specify custom column names, you can employ the `createdAt` and `updatedAt` options.

### `softDelete`

```dart
@DoxModel(softDelete: true)
```


## Table column

### Name

=== "Default"

    ```dart
    @column()
    String? title;
    ```

=== "Custom column name"

    ```dart
    @column(name: 'user_id')
    String? userId;
    ```

### Hooks

=== "beforeSave"

    ```dart
    @DoxModel()
    class Blog extends BlogGenerator {
        @column(beforeSave: getSlugFromTitle)
        String? slug

        static getSlugFromTitle(Map<String, dynamic> map) {
            return slugify(map['title']);
        }
    }
    ```

=== "beforeGet"

    ```dart
    @DoxModel()
    class Blog extends BlogGenerator {
        @column(name: 'published_at', beforeGet: convertToHumanReadable)
        DateTime? publishedAt

        static convertToHumanReadable(Map<String, dynamic> map) {
            var format = DateFormat.yMd('us');
            var dateString = format.format(DateTime.parse(map['published_at']));
        }
    }
    ```

!!! warning
    `beforeSave` and `beforeGet` hook must be static function inside Model class.


## Save

=== "Save a new record"

    ```dart
    Blog blog = Blog();
    blog.title = 'title';
    await blog.save();
    ```

=== "Set a field to null"

    ```dart
    Blog? blog = await Blog().find(1);
    blog?.slug = null;
    await blog?.save(); // slug is now NULL in the database
    ```

!!! info
    On insert, `null` fields are not sent, so the database default is used.
    On update, a field is set to `NULL` only when it had a value before
    (loaded from the database or saved). Fields that were not loaded,
    for example with `select()`, are not changed.

## Delete

=== "Delete a record"

    ```dart
    Blog? blog = await Blog().find(1);
    await blog?.delete(); // only deletes this record
    ```

=== "Restore a soft deleted record"

    ```dart
    Blog? blog = await Blog().withTrash().find(1);
    await blog?.restore(); // sets deleted_at back to NULL
    ```

!!! info
    `save()`, `delete()`, `forceDelete()` and `restore()` fire [model events](events.md).

## To map

=== "To map"

    ```dart
    Map<String, dynamic> blog = await Blog().find(1).toMap();
    ```

## Debug

=== "Debug"

    ```dart
    Blog blog = blog();
    blog.debug(true);
    blog.name = 'John Wick';
    await blog.save();
    ```

!!! info
    Debug `true` option will print the SQL query in the console/terminal.

## New query

!!! info
    If you do not want to create new class and reuse existing class to do new query, use can use `query()` function.

=== "Example"

    ```dart
    Blog blog = Blog();
    List<Blog> blogs = await blog.where('status', 'active')
        .where('user', 'super_user').get();

    // reset existing get query and make new one using `query()`
    List<Blog> blog = await blog.query()
        .where('status', 'deleted').where('user', 'normal').get();
    ```

## Hide column

=== "Example"

    ```dart
    @DoxModel()
    class User extends UserGenerator {
        @override
        List<String> get hidden => ['password', 'remember_token'];
    }
    ```

## Computed values

A computed value is a getter that is added to `toJson()` and `toMap()`.
It is like `$appends` with an accessor in Laravel.

Add `@Computed()` to a getter in the model, then run `dart run build_runner build`.

```dart
@DoxModel()
class User extends UserGenerator {
  @Column(name: 'first_name')
  String? firstName;

  @Column(name: 'last_name')
  String? lastName;

  @Computed() // json key: full_name
  String get fullName => '$firstName $lastName';

  @Computed(name: 'initials') // custom json key
  String get shortName => '${firstName?[0]}${lastName?[0]}';
}
```

```dart
User? user = await User().find(1);
print(user?.toJson());
// {id: 1, first_name: John, last_name: Wick, ..., full_name: John Wick, initials: JW}
```

- The default key is the getter name in snake_case (`fullName` becomes `full_name`).
- A computed value is **never a column**. It is not read from the database, and it is not sent in `INSERT` or `UPDATE`.
- `hidden` also hides computed values. Use the json key, for example `['full_name']`.
- Computed values of loaded relations are in the nested json too.
- `toMap(original: true)` returns the raw database row, so it has no computed values.

!!! info "Performance"
    The code is made by `build_runner`. There is no reflection.
    A model without `@Computed()` does no extra work in `toJson()`.
    A getter runs each time `toJson()` or `toMap()` is called, so keep it fast.

!!! info "Casts"
    Dox has no `$casts` list. The field type does the cast:
    `DateTime?` is parsed from the database, and a JSON column can be a
    `Map<String, dynamic>?` or `List<dynamic>?` field.
    For other conversions, use the `beforeSave` and `beforeGet` hooks of `@Column`.

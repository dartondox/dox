# Model

## Create

=== "Create"

    ```bash
    dox create:model Blog
    ```

=== "With migration"

    ```bash
    dox create:model Blog -m
    ```

!!! info
    This will create a blog model inside `lib/models` folder.


!!! warning
    Please run `dart run build_runner build` after new model is created. Alternatively can also run build_runner watch `dart run build_runner watch` to update changes to generator file


=== "Sample Model"

```dart
import 'package:dox_query_builder/dox_query_builder.dart';
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
    List Blog> blogs = await blog.where('status', 'active')
        .where('user', 'super_user').get();

    // reset existing get query and make new one using `query()`
    List Blog> blog = await blog.query()
        .where('status', 'deleted').where('user', 'normal').get();
    ```

## Hide column

=== "Example"

    ```dart
    @DoxModel()
    class User extends UserGenerator {
        @override
        List String> get hidden => ['password', 'remember_token'];
    }
    ```
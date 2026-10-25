# dox_orm

Models, relations and a query builder for Postgres, MySQL, MariaDB and SQLite.

[![pub package](https://img.shields.io/pub/v/dox_orm.svg)](https://pub.dev/packages/dox_orm)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/develop/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

```bash
dart pub add dox_orm
```

Dox 3.x is in alpha (`3.0.0-alpha.x`). The API can still change before the stable release.

## Use it

Set up the connection once:

```dart
import 'package:dox_orm/dox_orm.dart';

DatabaseConfig databaseConfig = DatabaseConfig(
  connection: 'sqlite',
  connections: <String, ConnectionConfig>{
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: 'storage/app.db', // file path, or ':memory:'
    ),
  },
);

SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig);
```

Write a model. `dox_builder` makes the `BlogGenerator` class
(`dart pub add dev:dox_builder dev:build_runner`, then `dart run build_runner build`):

```dart
part 'blog.model.g.dart';

@DoxModel(table: 'blogs')
class Blog extends BlogGenerator {
  @Column()
  String? title;

  @Column()
  String? status;
}
```

Use it:

```dart
Blog blog = Blog();
blog.title = 'Hello';
blog.status = 'active';
await blog.save();

List<Blog> active = await Blog().where('status', 'active').orderBy('id', 'desc').get();
Blog? one = await Blog().find(1);

// no model: a list of maps
List<Map<String, dynamic>> rows = await QueryBuilder.table('blogs').where('id', '>', 10).get();
```

In a Dox app, start the ORM in a `DoxService`, so each isolate gets its own pool.

## Features

- One API for Postgres, MySQL 8+, MariaDB and SQLite.
- Postgres and MySQL use the native Rust drivers (`dox_postgres_native`, `dox_mysql_native`). When the native library does not load, the app stops with an error that says why and how to fix it.
- Models with `@Column`, timestamps, soft deletes, events and `hidden` fields.
- Relations: `@HasOne`, `@HasMany`, `@BelongsTo`, `@ManyToMany`, with eager loading.
- Query builder: `where`, `whereIn`, `join`, `groupBy`, `paginate`, raw SQL with bound values.
- Transactions with `QueryBuilder.transaction()`.
- Schema builder for migrations (used by `dox_migration`).
- DTO rules `@Unique` and `@Exists` that check the database.

## Documentation

- [Database setup](https://dartondox.dev/latest/database/)
- [Query builder](https://dartondox.dev/latest/database/query-builder/), [Models](https://dartondox.dev/latest/database/model/), [Transactions](https://dartondox.dev/latest/database/transactions/)
- [API reference](https://pub.dev/documentation/dox_orm/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/develop/LICENSE).

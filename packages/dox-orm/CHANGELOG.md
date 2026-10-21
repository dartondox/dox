## 3.0.0-alpha.1

- Renamed from `dox_query_builder` to `dox_orm`. Change `package:dox_query_builder/dox_query_builder.dart` to `package:dox_orm/dox_orm.dart`. The old package still works for now: it only re-exports this one.
- Added SQLite (`Driver.sqlite`, package `sqlite3`). `database` is a file path or `:memory:`. Uses WAL, `busy_timeout` and foreign keys. One connection per isolate. See the docs for limits.
- MySQL driver is now `mysql_dart` (was `mysql1`). The MySQL 8 default login (`caching_sha2_password`) works. It uses a real connection pool (`maxConnectionCount`, default 10), prepared statements with bound values, and one pooled connection per transaction.
- Breaking: `extra['characterSet']` (a `mysql1` type) is no longer read. Use `extra['collation']` (default `utf8mb4_general_ci`). `getDatabaseConnection()` for MySQL now returns a `MySQLConnectionPool`.
- Breaking: MySQL `TIME` columns are now a `String` (was a `Duration`). `BLOB` columns are `Uint8List` (was text).
- `ConnectionConfig`: `user`, `password` and `port` are optional (not used by SQLite).
- Needs Dart 3.6 or newer.
- Added `whereNull`, `whereNotNull`, `orWhereNull`, `orWhereNotNull`, `whereNotIn`, `orWhereIn`, `orWhereNotIn` and `selectRaw`.
- Added `QueryBuilder.transaction()`. Postgres now uses a real connection pool (`maxConnectionCount`) and no longer runs each query in its own transaction.
- Added `boolean()` schema column (Postgres `BOOLEAN`, MySQL `TINYINT(1)`, read as `bool`).
- Table and column names are now quoted (`"name"` on Postgres, `` `name` `` on MySQL). On Postgres, quoted names are case sensitive. Use `selectRaw`/`whereRaw` for raw SQL.
- `count()` ignores `limit`, `offset` and `orderBy`. With `groupBy` it now returns the number of groups (before: the size of the first group).
- `save()` can set a field to null on update.
- `insert()` works with any primary key type (uuid strings too).
- `model.delete()` and `model.forceDelete()` only delete that record. Before, they had no where condition.
- `forceDelete()` also deletes soft deleted rows. `withTrash(false)` on a model without soft deletes no longer adds a `deleted_at` filter.
- hasOne, hasMany and manyToMany work with a custom `localKey`.
- `insertMultiple()` uses keys from all rows. Missing keys use the column default.
- MySQL: only JSON columns are decoded (arrays too). MariaDB keeps decoding JSON-like text, because it stores JSON as text.
- Schema: `unique()` on a column that is already unique is skipped. Default values are escaped.

## 2.1.0

- Added support for MYSQL driver

## 2.0.0

- Support postgres driver v3

## 1.1.16

- Bug fixed on save
- Change `newQuery` to `query()` and deprecate `newQuery`

## 1.1.15

- Bug fixed on toMap

## 1.1.14

- Bug fixed on eager/preload data missing in `toMap` response.
- Bug fixed on `deleted_at` column conflict.
- Support for `withTrash` chain on any query builder function.

## 1.1.13

- Update readme
- bug fixed on count() with order by

## 1.1.12

- Add support for paginate() function
- Add support for query printer, file printer, consoler printer and pretty printer.

## 1.1.11

- Add missing types on function and arguments
- Bug fixed on count, custom query

## 1.1.10

- Remove hidden fields on toJson

## 1.1.9

- Bug fixed on jsonEncode(Model)

## 1.1.8

- Update readme

## 1.1.7

- Add option in `toMap()` to remove hidden fields

## 1.1.6

- Create own annotation and builder
- Added belongsTo support
- Added hasOne support
- Added hasMany support
- Added manyToMany support
- Added eager loading support

## 1.0.11

- Bug fixed id null on save

## 1.0.10

- Bug fixed on debug option in model
- Bug fixed on debug query param missing
- Support Postgres Pool
- Support hidden fields in model

## 1.0.1

- Update documentation

## 1.0.0

- Initial release

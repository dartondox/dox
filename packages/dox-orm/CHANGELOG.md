## 3.0.0-alpha.6

- MySQL and MariaDB Unix sockets. A host that starts with `/` is the socket file, like `/var/run/mysqld/mysqld.sock` or `/cloudsql/project:region:instance` on Cloud Run. Works on the native and the Dart driver. In a url, use `?socket=/path` or `?host=/path`.
- New `SqlQueryBuilder.close()`. It closes every open database connection of the isolate: the default and all named connections, on every driver (native Postgres and MySQL, the Dart drivers and SQLite). It is safe to call twice. Call it on shutdown, eg. from a `DoxShutdown` service.
- New `DBDriver.close()`, for one driver. Custom drivers can override it. The default does nothing.
- `SqlQueryBuilder().dbDriver` throws a `StateError` with a clear message when the ORM is not set up (or after `close()`).
- After `close()`, the native MySQL driver throws a `StateError` on a new query or transaction. Before, the query still ran when another isolate kept the shared pool open.

## 3.0.0-alpha.5

- `DATABASE_URL` support. `ConnectionConfig.fromUrl()` reads `postgres://`, `postgresql://`, `mysql://`, `mariadb://`, `sqlite:` and `file:` urls: url-decoded user and password, host, port, database, `sslmode` and other options (they go to `extra`).
- `DatabaseConfig` has a new `url`. It is `DATABASE_URL` from the environment when not given. When it is set, it wins: it replaces the default connection. Pass `url: ''` to turn it off.
- Postgres Unix sockets. A host that starts with `/` is a socket folder, like `/cloudsql/project:region:instance` on Cloud Run. Works on the native and the Dart driver. Use `?host=/cloudsql/...` in a url.
- Breaking: the finders are typed. On a model, `get()` and `all()` give `Future<List<T>>`, `find()` and `getFirst()` give `Future<T?>`, and `paginate()` gives `Future<Pagination<T>>` (`page.data` is a `List<T>`). `QueryBuilder.table()` gives maps: `get()` is `Future<List<Map<String, dynamic>>>` and `getFirst()` is `Future<Map<String, dynamic>?>`. `QueryBuilder.table()` has no type argument and no second argument any more.
- Breaking: `groupBy()` and `rawQuery()` rows are maps, so use them on `QueryBuilder.table()`. On a model, `get()` throws a `StateError` for them. `count()` with `groupBy()` still works on a model.
- Breaking: the default foreign keys use the model name, like Laravel. A `User` model with `table: 'users'` gives `user_id`, not `users_id`. The default pivot table of `@ManyToMany` also uses the model names (`artist_song`). Keys you set yourself work as before. New `Model.foreignKeyName` gives the default key of a model.
- Breaking: `save()` inserts when the model is new and updates when the row is in the table (`model.exists`). Before, it updated when the primary key was set. So a new model with a key you set yourself, like a UUID, is now inserted.
- `QueryBuilder.query()` has a new `connection` parameter, to run a raw query on a named connection.
- Fix: `withConnection()` did not reach `save()`, `delete()`, `forceDelete()` and `restore()`. They used the default connection. Now they use the connection of the model. Models that a query returns keep the connection of the query, and relation queries use the connection of the parent model. `Model.withConnection()` returns the model, so `Blog()..withConnection('other')` works.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Postgres and MySQL/MariaDB now use the native drivers by default (`dox_postgres_native` and `dox_mysql_native`). You do not change any config. If the native library does not load, the ORM uses the Dart driver and prints one warning line. Set `DOX_DB_DRIVER=dart`, or `extra: {'native': false}` on one connection, to use the Dart driver. `driverFactory` still wins over all of this.
- Breaking: `PostgresNativeDriver` and `MysqlNativeDriver` moved into `dox_orm`. Import them from `package:dox_orm/dox_orm.dart`.
- `PostgresNativeDriver.query` does one less async step per query.
- Faster queries on all databases. Each connection keeps its prepared statements (LRU, 100 by default, `extra['preparedStatementCacheSize']`). The same query now has the same sql text, so the statements are reused. `find()` no longer sends `LIMIT 1 OFFSET 0`: LIMIT and OFFSET are only sent when set, and never `OFFSET 0`. Less work per row when models are built. A find by id on SQLite went from 23 µs to 6 µs.
- Less Dart work per query. A plain `find()` builds its SQL once per driver, table and column, and reuses it. A model makes its maps and lists only when they are used. Rows become models without one more `await` when there is nothing to preload. ORM work per `World().find(id)` went from 2.6 µs to 1.0 µs (no database, AOT).
- New `ConnectionConfig.driverFactory`: plug in your own driver class with one line. The default and the named connections use it.

## 3.0.0-alpha.2

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- `sqlite3` 3. SQLite is now bundled by a build hook, so no system `libsqlite3` is needed.
- Breaking: `dart compile exe` does not work with build hooks. Use `dart build cli` (or `dox build`).
- SQLite: set `busy_timeout` before `journal_mode = WAL`. Before, many isolates that opened the same file at start could fail with "database is locked".
- New DTO rules `@Unique('users', column: 'email', ignoreParam: 'id')` and `@Exists('teams')`. They run after all other checks. A `List` field is checked with one `WHERE IN` query. Soft-deleted rows count too.


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

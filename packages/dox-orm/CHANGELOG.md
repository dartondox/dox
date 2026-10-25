## 3.0.0-alpha.9

- Breaking: the `ModelObserver` methods now have the same names as the model hooks: `onSaving`, `onSaved`, `onCreating`, `onCreated`, `onUpdating`, `onUpdated`, `onDeleting`, `onDeleted`, `onRestoring`, `onRestored`, `onForceDeleting` and `onForceDeleted`. Rename the methods in your observers, for example `created(User user)` to `onCreated(User user)`.
- New model factories: `import 'package:dox_orm/factory.dart';`. Extend `Factory<User>` and write `definition()`. Then use `count(n)`, `state()`, `sequence()`, `has()`, `make()`, `makeOne()`, `create()` and `createOne()`. See the Factories docs page.
- New query scopes. `@Scope()` on a static model method adds it as a query method, like `User().isActive().get()`. `@Scope(global: true)` adds it to every query of the model. Remove it with `withoutGlobalScope('name')` or `withoutGlobalScopes()`.
- New attribute casts with `@Column(cast: ...)`: `JsonCast`, `ListCast<E>`, `BoolCast`, `EnumCast<E>` (by name or by index), or your own `Cast<T>` class. `bool` fields get `BoolCast` and enum fields get `EnumCast` without `cast`.
- New `withCount('posts')`, `withSum('posts', 'views')` and `withMax('posts', 'views')`. They add the value with a subquery, for `hasOne`, `hasMany` and `manyToMany` relations. Read it with `countOf('posts')` or `aggregate('posts_sum_views')`. `toJson()` has it too.
- `all()` now uses the where conditions of the query, like `get()`. Before, it used only the soft delete check.
- New: `package:dox_orm/testing.dart` with `refreshDatabase()`. Use `setUp(refreshDatabase)` in tests: it empties every table and starts the ids at 1 again, on Postgres, MySQL, MariaDB and SQLite. The migrations table keeps its rows. `keep:` keeps more tables.

## 3.0.0-alpha.8

- A `transaction()` inside another transaction now uses a savepoint (`SAVEPOINT sp_N`). When the inner function throws, only its work is undone, and the error is thrown again. If the caller catches the error, the outer transaction goes on and can commit. Before, the inner one joined the outer one, so an inner error always undid the outer work too. Works on Postgres, MySQL, MariaDB and SQLite. New `DBDriver.savepoint()`.
- Postgres: new `extra['sslRootCert']`, the path of a PEM file with the CA certificates to trust for `verify-full`. `sslrootcert` in `DATABASE_URL` sets it. New `ConnectionConfig.postgresSslRootCert`. Needs the next `dox_postgres_native` release.

## 3.0.0-alpha.7

- Breaking: Postgres and MySQL use only the native drivers. The Dart drivers (`postgres` and `mysql_dart` packages) are gone. So are `PostgresDriver`, `MysqlDriver`, `DOX_DB_DRIVER=dart` and `extra['native']`.
- Breaking: when the native library does not load, `createDriver()` and `SqlQueryBuilder.initializeWithDatabaseConfig()` throw an `UnsupportedError`. It says why the library did not load and how to fix it. Before, the ORM used the Dart driver and printed a warning.
- Postgres has TLS now. `useSSL: true` is mode `require` (no certificate check, like libpq). `extra['sslMode']` is a `String`: `disable`, `prefer`, `require` or `verify-full`. `sslmode` in `DATABASE_URL` sets it. `prefer` and `allow` in the url now mean "TLS when the server has it".
- Breaking: errors are `PgServerException` and `PgException` for Postgres, and `MysqlException` for MySQL. `dox_orm` exports them. The `ServerException` classes of the `postgres` package and `MySQLServerException` are gone.
- Breaking: `ConnectionConfig` loses `getDatabaseConnection()`, `postgresEndpoint`, `mysqlHost`, `mysqlPort`, `mysqlAllowPublicKeyRetrieval` and `mysqlAcceptBadCertificate`. `postgresSslMode` is now a `String`. The `collation`, `timeoutMs`, `timeZone` (MySQL), `serverPublicKey`, `allowPublicKeyRetrieval` and the `postgres` package pool keys of `extra` are no longer read.
- Breaking: `getDatabaseDriver()` and `SqlQueryBuilder.initialize()` take a `PgNativePool` for Postgres and a `MysqlNativePool` for MySQL.
- On Postgres, a `List` in `insert()` or `update()` is sent as json text, so it fits a json column. New `DBDriver.columnValue()`.
- `dox_postgres_native` and `dox_mysql_native` now live in their own repos (dartondox/dox-postgres-native, dartondox/dox-mysql-native). Dox uses them from pub.dev (`^3.0.0-alpha.7`). Their build hooks download ready-built libraries, so you do not need Rust.
- Faster `belongsTo` load. It reads each owner once with `WHERE owner.id IN (...)`, with no join to the children. Before, a user with 10,000 blogs came back 10,000 times. Children of the same owner now get the same model object.
- `save()` on a new model runs one `INSERT` and reads the id from it. There is no `SELECT` after it. `insert()` and `create()` use `RETURNING *` on Postgres and SQLite, so they also skip the `SELECT`. MySQL still reads the row with `find()`.
- `save()` on an existing model sends only the columns that changed since the last load or save. A `Map` or `List` field is always sent. When nothing changed, `save()` runs no query and `updated_at` stays as it is. Before, it always ran an `UPDATE` with every column that had a value.
- Fix: after `restore()`, a `save()` on the same model sent the old `deleted_at` again and deleted the row again. Now `deleted_at` is not sent, because it did not change.
- `LIMIT` and `OFFSET` are bound parameters (`@dox_limit`, `@dox_offset`). Every page gives the same SQL, so the drivers reuse one prepared statement.
- On Postgres, `whereIn` and `whereNotIn` with only `int` or only `String` values send one array parameter (`= ANY(@p)`, `<> ALL(@p)`). A list of any size gives the same SQL. Other lists keep one parameter per value.
- Relations of one model (`preload` and `eager`) load at the same time outside a transaction, so the native drivers send them in one batch. Inside a transaction they still load one by one. New `DBDriver.inTransaction`.
- Rows of a model made by the new generator skip the date to string step. `fromMap()` takes the `DateTime` of the driver as it is. `toMap(original: true)` still gives dates as ISO strings.
- New `Model.columnsToMap()`: the columns only, without relations. `save()` uses it, so it no longer turns preloaded relations into JSON.
- Less work per row: the where, join and order lists of a model are made only when used. `getPreload()` and the generated getters do not make a new list or map on each call.
- The SQL text is no longer scanned for double spaces on each query. `orderBy()` without a direction no longer adds a space.
- `QueryBuilderHelper.runQuery()` no longer has the `clean` parameter.
- Fix: in a native Postgres or MySQL `transaction()`, when the rollback after an error also fails, the first error is thrown. Before, the rollback error replaced it.
- The native Postgres driver shares one pool for all isolates with the same settings, like the native MySQL driver. `maxConnectionCount` is for the whole process on both native drivers.
- The Dart Postgres driver keeps its prepared statements after a session command like `SET`, `SHOW`, `BEGIN` or `COMMIT`. Before, any query that was not select/insert/update/delete dropped all of them.
- Breaking: column and table names in `select`, `where`, `orderBy`, `groupBy`, `join`, `insert` and `update` must be plain names (`name`, `table.name`, `table.*`, `*`, `name as alias`). Anything else, like `count(*)`, throws an `ArgumentError`. Before, a name with `(` went into the SQL as it is, so user input could add SQL. Use `selectRaw`, `whereRaw` or the new `orderByRaw` and `groupByRaw` for expressions.
- Breaking: the operator of `where()` and `join()` must be one of `=`, `!=`, `<>`, `<`, `>`, `<=`, `>=`, `like`, `not like`, `ilike` (any case). Any other value throws an `ArgumentError`.
- New `fillable` and `guarded` lists on `Model`. When set, `create()`, `insert()` and `update()` on the model drop the keys that are not allowed, so `User().create(req.body)` can not set `is_admin`. `insertMultiple()` on the model drops them from each row too. Both are empty by default, so nothing changes until you set them.
- Breaking: TLS checks the server certificate. Postgres `useSSL` (and `sslmode=verify-ca` or `verify-full` in a url) now uses `SslMode.verifyFull`. `sslmode=require` in a url stays `SslMode.require` like libpq: it encrypts but does not check the certificate (eg. Heroku). The Dart MySQL driver no longer accepts a bad certificate. Set `extra['verifyCertificate']` to false (or `?verifyCertificate=false` in a url) to skip the check for a self-signed certificate in development.
- Breaking: the Dart MySQL driver no longer asks the server for its RSA key by default. It still asks with TLS on, or on `localhost`, `127.0.0.1`, `::1` and a Unix socket. Give the key in `serverPublicKey`, or set `allowPublicKeyRetrieval: true`.

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

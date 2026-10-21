# Schema builder

The schema builder creates, changes and drops tables.
The same code works on Postgres, MySQL, MariaDB and SQLite.
You mostly use it inside a [migration](migration.md).

```dart
await schema.create('posts', (Table table) {
  table.id();
  table.foreignId('user_id').constrained().cascadeOnDelete();
  table.string('title');
  table.text('body').nullable();
  table.enumeration('status', <String>['draft', 'published']).defaultTo('draft');
  table.timestamps();
});
```

## Get a schema

In a migration, `up` and `down` get a `Schema`. It runs on the migration connection.

Outside a migration, `Schema()` uses the query builder connection.
You can also give a driver: `Schema(driver)`.

```dart
Schema schema = Schema();
await schema.dropIfExists('posts');
```

## Tables

| Method | What it does |
|---|---|
| `create('t', (Table table) {...})` | Create table `t`. It fails when the table exists. |
| `table('t', (Table table) {...})` | Change table `t`: add columns, change columns, keys. |
| `drop('t')` | Drop table `t`. It fails when the table is missing. |
| `dropIfExists('t')` | Drop table `t` when it exists. |
| `rename('from', 'to')` | Rename a table. |
| `hasTable('t')` | `true` when the table exists. |
| `hasColumn('t', 'c')` | `true` when the column exists. |
| `getColumnListing('t')` | The column names, in order. |

## Column types

| Method | Postgres | MySQL / MariaDB | SQLite |
|---|---|---|---|
| `id()` / `bigIncrements('id')` | `BIGSERIAL PRIMARY KEY` | `BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY` | `INTEGER PRIMARY KEY AUTOINCREMENT` |
| `increments('id')` | `SERIAL PRIMARY KEY` | `INT UNSIGNED AUTO_INCREMENT PRIMARY KEY` | `INTEGER PRIMARY KEY AUTOINCREMENT` |
| `string('c', [255])` | `VARCHAR(n)` | `VARCHAR(n)` | `VARCHAR(n)` |
| `char('c', [255])` | `CHAR(n)` | `CHAR(n)` | `CHAR(n)` |
| `text('c')` | `TEXT` | `TEXT` | `TEXT` |
| `mediumText('c')` | `TEXT` | `MEDIUMTEXT` | `TEXT` |
| `longText('c')` | `TEXT` | `LONGTEXT` | `TEXT` |
| `integer('c')` | `INTEGER` | `INT` | `INTEGER` |
| `bigInteger('c')` | `BIGINT` | `BIGINT` | `INTEGER` |
| `smallInteger('c')` | `SMALLINT` | `SMALLINT` | `INTEGER` |
| `tinyInteger('c')` | `SMALLINT` | `TINYINT` | `INTEGER` |
| `unsignedInteger('c')` (and `unsignedBigInteger`, `unsignedSmallInteger`, `unsignedTinyInteger`) | signed type | `... UNSIGNED` | `INTEGER` |
| `float('c')` | `REAL` | `FLOAT` | `FLOAT` |
| `double('c')` | `DOUBLE PRECISION` | `DOUBLE` | `DOUBLE` |
| `decimal('c', [8], [2])` | `DECIMAL(p, s)` | `DECIMAL(p, s)` | `DECIMAL(p, s)` |
| `boolean('c')` | `BOOLEAN` | `TINYINT(1)` | `BOOLEAN` |
| `date('c')` | `DATE` | `DATE` | `DATE` |
| `dateTime('c')` | `TIMESTAMP` | `DATETIME` | `DATETIME` |
| `dateTimeTz('c')` | `TIMESTAMPTZ` | `DATETIME` | `DATETIME` |
| `time('c')` | `TIME` | `TIME` | `TIME` |
| `timestamp('c')` | `TIMESTAMP` | `TIMESTAMP` | `TIMESTAMP` |
| `timestampTz('c')` | `TIMESTAMPTZ` | `TIMESTAMP` | `TIMESTAMP` |
| `json('c')` / `jsonb('c')` | `JSONB` | `JSON` | `JSON` |
| `uuid([uuid])` | `UUID` | `CHAR(36)` | `TEXT` |
| `binary('c')` | `BYTEA` | `BLOB` | `BLOB` |
| `enumeration('c', ['a', 'b'])` | `VARCHAR(255)` + `CHECK` | `ENUM('a', 'b')` | `VARCHAR(255)` + `CHECK` |
| `foreignId('user_id')` | `BIGINT` | `BIGINT UNSIGNED` | `INTEGER` |
| `foreignUuid('user_id')` | `UUID` | `CHAR(36)` | `TEXT` |

Helpers:

- `timestamps()`: nullable `created_at` and `updated_at` (`timestampTz`).
- `softDeletes([deleted_at])`: nullable `deleted_at` (`timestampTz`), for `SoftDeletes` models.
- `rememberToken()`: nullable `remember_token` `VARCHAR(100)`.
- `morphs('owner')`: `owner_id` (unsigned big integer), `owner_type` (string) and an index on both.

!!! info "JSON on SQLite"
    SQLite has no JSON type. The column is declared as `JSON`,
    so the SQLite driver knows to decode it when you read it.

## Modifiers

Modifiers come after the column type. They can be chained:
`table.string('email').nullable().unique()`.

| Modifier | What it does | Notes |
|---|---|---|
| `nullable()` | Allow `NULL`. Columns are `NOT NULL` by default. | `nullable(false)` makes it `NOT NULL` again. |
| `defaultTo(value)` | Default value. Strings are escaped, so any text is safe. | `bool`, numbers, `null`, `Map`/`List` (saved as JSON) and `DateTime` work too. `withDefault` is the old name. |
| `defaultRaw('sql')` | Default as raw SQL. It is **not** escaped. | Put expressions in `( )`: `defaultRaw('(1 + 1)')`. MySQL and SQLite need it. |
| `useCurrent()` | Default to the current time. | Same as `defaultRaw('CURRENT_TIMESTAMP')`. |
| `useCurrentOnUpdate()` | Set the current time on each update. | MySQL only. Postgres and SQLite ignore it. Set the time in your code there. |
| `unique()` | Add a unique index `{table}_{column}_unique`. | |
| `index()` | Add an index `{table}_{column}_index`. | |
| `primary()` | Make the column the primary key. | |
| `unsigned()` | `UNSIGNED`. | MySQL only. Others ignore it. |
| `comment('text')` | Column comment. | Postgres and MySQL. SQLite ignores it. |
| `after('column')` | Put the new column after another one. | MySQL only, only in `schema.table`. Others add it at the end. |
| `change()` | Change an existing column (in `schema.table`). | See [Change columns](#change-columns). |

!!! info "MySQL defaults on TEXT and JSON"
    MySQL only allows a default on `TEXT`, `BLOB` and `JSON` as an expression.
    The schema builder writes it as `DEFAULT ('value')` for you.

## Change a table

```dart
await schema.table('users', (Table table) {
  table.string('avatar').nullable().after('email'); // add
  table.string('name', 100).nullable().change();    // change
  table.renameColumn('bio', 'about');
  table.dropColumn('age');
  table.dropColumns(<String>['a', 'b']);
});
```

A column in `schema.table` is **added**. Add `.change()` to change a column that exists.

### Change columns

`change()` sets the full new column: type, null, default and comment.
Give every modifier you want to keep.

```dart
// before: string('title') NOT NULL DEFAULT 'x'
table.string('title', 500).nullable().defaultTo('x').change();
```

How it runs:

| Driver | SQL |
|---|---|
| Postgres | One `ALTER TABLE`: `ALTER COLUMN ... TYPE ... USING col::type`, `SET/DROP NOT NULL`, `SET/DROP DEFAULT`, and the enum `CHECK` again. |
| MySQL | `ALTER TABLE ... MODIFY COLUMN <full column>`. |
| SQLite | SQLite can not change a column. Dox makes the table again (see below). |

`change()` with `unique()` or `index()` adds the index. It fails when the index already exists.

## Indexes and keys

`columns` is a column name or a list of names.

```dart
table.index(<String>['state', 'created_at']);  // posts_state_created_at_index
table.unique('slug');                          // posts_slug_unique
table.primary(<String>['post_id', 'tag_id']);  // composite primary key

table.dropIndex(<String>['state', 'created_at']); // by columns
table.dropUnique('posts_slug_unique');            // or by name
```

Index names are `{table}_{columns}_{index|unique|foreign}`.
You can give your own name as the last argument: `table.unique('slug', 'my_name')`.

### Foreign keys

```dart
table.foreignId('user_id').constrained().cascadeOnDelete();
// same as:
table.foreignId('user_id');
table.foreign('user_id').references('id').on('users').onDelete('cascade');
```

- `constrained([table], [column = 'id'])` guesses the table from the column:
  `user_id` becomes `users`, `category_id` becomes `categories`.
  Dox models use singular table names by default (`User` is `user`).
  If your table is singular, give it: `constrained('user')`.
- Actions: `onDelete('cascade' | 'set null' | 'restrict' | 'no action')`, `onUpdate(...)`,
  and the short ones `cascadeOnDelete()`, `nullOnDelete()`, `restrictOnDelete()`, `cascadeOnUpdate()`.
- Put `nullable()` before `constrained()`: `table.foreignId('editor_id').nullable().constrained('users')`.
- Drop it: `table.dropForeign(<String>['user_id'])` or `table.dropForeign('posts_user_id_foreign')`.

!!! warning "Same type on both sides"
    `id()` is a big integer. `foreignId()` is a big integer too, so they match.
    If the parent uses `increments()` (a normal integer), use `unsignedInteger()` for the child on MySQL.

## SQLite notes

SQLite `ALTER TABLE` can only add, rename and drop columns.
For these changes, Dox makes the table again:

- `change()` of a column,
- `foreign(...)` on an existing table,
- `dropForeign(...)`.

It makes a new table with the change, copies the rows, drops the old table and renames the new one.
It keeps the columns, primary key, `AUTOINCREMENT`, foreign keys, indexes and enum checks.
All of it runs in one transaction.
It fails on tables with other `CHECK` constraints or with generated columns.

Other SQLite limits:

- `primary(...)` on an existing table is not supported.
- A new column that is `NOT NULL` needs a default. A new column can not default to `CURRENT_TIMESTAMP`.
- `dropColumn` fails when the column is in an index or a foreign key. Drop those first.

## Per driver notes

| Feature | Postgres | MySQL / MariaDB | SQLite |
|---|---|---|---|
| `enumeration` | `CHECK (col IN (...))` | `ENUM(...)` | `CHECK (col IN (...))` |
| `unsigned` | ignored | `UNSIGNED` | ignored |
| `comment` | `COMMENT ON COLUMN` | inline `COMMENT` | ignored |
| `after` | ignored | `AFTER col` | ignored |
| `useCurrentOnUpdate` | ignored | `ON UPDATE CURRENT_TIMESTAMP` | ignored |
| `change()` | `ALTER COLUMN` | `MODIFY COLUMN` | table rebuild |
| add/drop foreign key on a table | `ALTER TABLE` | `ALTER TABLE` | table rebuild |
| schema changes in a transaction | yes | no, saved right away | yes |
| index name length | 63 | 64 | no limit |

## See the SQL

Every change is a `Table` blueprint. A grammar turns it into SQL, without a database:

```dart
Table table = Table('users', creating: true)
  ..id()
  ..string('email').unique();
print(table.toSql(PostgresGrammar()));
// [CREATE TABLE "users" ("id" BIGSERIAL NOT NULL PRIMARY KEY, "email" VARCHAR(255) NOT NULL),
//  CREATE UNIQUE INDEX "users_email_unique" ON "users" ("email")]
```

Grammars: `PostgresGrammar`, `MysqlGrammar` and `SqliteGrammar`.
On SQLite, the changes that need a table rebuild only run on a database.

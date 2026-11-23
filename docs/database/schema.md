---
icon: lucide/table
---

# Schema builder

The schema builder creates, changes and drops tables with Dart code that works on Postgres, MySQL, MariaDB and SQLite.

You mostly use it inside a [migration](migration.md). There, `up` and `down` get a `Schema` that runs on the migration connection:

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

If you need a schema outside a migration, `Schema()` uses the query builder connection. You can also give a driver with `Schema(driver)`:

```dart
Schema schema = Schema();
await schema.dropIfExists('posts');
```

## Tables

### Creating tables

Use `create` to make a new table. The second argument is a function that adds the columns. It fails when the table already exists:

```dart
await schema.create('users', (Table table) {
  table.id();
  table.string('email');
});
```

### Updating tables

Use `table` to change a table that exists. You can add columns, change columns and add keys:

```dart
await schema.table('users', (Table table) {
  table.string('avatar').nullable();
});
```

### Renaming and dropping tables

Use `rename` to rename a table:

```dart
await schema.rename('posts', 'articles');
```

Use `drop` to drop a table. It fails when the table is missing, so use `dropIfExists` if the table may not be there:

```dart
await schema.drop('users');

await schema.dropIfExists('users');
```

### Checking tables and columns

Sometimes a migration must check what is already there. `hasTable`, `hasColumn` and `hasColumns` return `true` when the table or columns exist:

```dart
if (await schema.hasTable('users')) {
  // ...
}

if (await schema.hasColumn('users', 'email')) {
  // ...
}

await schema.hasColumns('users', <String>['name', 'email']);
```

`getColumnListing` returns the column names of a table, in order:

```dart
await schema.getColumnListing('users');
```

## Columns

### Available column types

Each column type is a method on `Table`. This table shows the SQL type that each database gets:

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
| `uuid(['uuid'])` | `UUID` | `CHAR(36)` | `TEXT` |
| `binary('c')` | `BYTEA` | `BLOB` | `BLOB` |
| `enumeration('c', ['a', 'b'])` | `VARCHAR(255)` + `CHECK` | `ENUM('a', 'b')` | `VARCHAR(255)` + `CHECK` |
| `foreignId('user_id')` | `BIGINT` | `BIGINT UNSIGNED` | `INTEGER` |
| `foreignUuid('user_id')` | `UUID` | `CHAR(36)` | `TEXT` |
| `foreignIdFor(User())` | `BIGINT` | `BIGINT UNSIGNED` | `INTEGER` |
| `ulid(['ulid'])` / `foreignUlid('user_id')` | `CHAR(26)` | `CHAR(26)` | `CHAR(26)` |
| `year('c')` | `INTEGER` | `YEAR` | `INTEGER` |
| `ipAddress(['ip_address'])` | `VARCHAR(45)` | `VARCHAR(45)` | `VARCHAR(45)` |

SQLite has no JSON type. The column is declared as `JSON`, so the SQLite driver knows to decode it when you read it.

### Column helpers

Some columns are needed in many tables, so Dox has helpers for them.

`timestamps` adds nullable `created_at` and `updated_at` columns (`timestampTz`):

```dart
table.timestamps();
```

`softDeletes` adds a nullable `deleted_at` column (`timestampTz`). You need it for models with `softDelete: true`:

```dart
table.softDeletes();
```

`morphs` adds the columns for a [polymorphic relation](model/relationship/polymorphic.md): `owner_id` (unsigned big integer), `owner_type` (string), and one index on both. Use `nullableMorphs` if both columns can be `NULL`, or `uuidMorphs` for a uuid `owner_id`:

```dart
table.morphs('owner');
```

`rememberToken` adds a nullable `remember_token` `VARCHAR(100)` column:

```dart
table.rememberToken();
```

### Column modifiers

Modifiers come after the column type, and you can chain them:

```dart
table.string('email').nullable().unique();
```

| Modifier | What it does |
|---|---|
| `nullable()` | Allow `NULL`. Columns are `NOT NULL` by default. `nullable(false)` makes it `NOT NULL` again. |
| `defaultTo(value)` | Set a default value. Strings are escaped, so any text is safe. `bool`, numbers, `null`, `Map`/`List` (saved as JSON) and `DateTime` work too. `withDefault` does the same. |
| `defaultRaw('sql')` | Set the default as raw SQL. It is **not** escaped. Put expressions in `( )`, like `defaultRaw('(1 + 1)')`, because MySQL and SQLite need it. |
| `useCurrent()` | Default to the current time. The same as `defaultRaw('CURRENT_TIMESTAMP')`. |
| `useCurrentOnUpdate()` | Set the current time on each update. MySQL only, so on Postgres and SQLite set the time in your code. |
| `unique()` | Add a unique index `{table}_{column}_unique`. |
| `index()` | Add an index `{table}_{column}_index`. |
| `primary()` | Make the column the primary key. |
| `unsigned()` | `UNSIGNED`. MySQL only. |
| `comment('text')` | Add a column comment. Postgres and MySQL only. |
| `collation('utf8mb4_bin')` | Set the column collation, for example so `A` and `a` are two keys. MySQL and MariaDB only, and only on text columns. |
| `after('column')` | Put the new column after another one. MySQL only, and only in `schema.table`. |
| `change()` | Change a column that exists. See [Modifying columns](#modifying-columns). |

### Modifying columns

In `schema.table`, a column is **added** by default. To change a column that exists, add `.change()`:

```dart
await schema.table('posts', (Table table) {
  table.string('title', 500).nullable().defaultTo('x').change();
});
```

`change()` sets the full new column: type, null, default and comment. So give every modifier you want to keep. For example, if the column had a default and you leave out `defaultTo`, the default is gone.

### Renaming columns

Use `renameColumn` to rename a column:

```dart
await schema.table('users', (Table table) {
  table.renameColumn('bio', 'about');
});
```

### Dropping columns

Use `dropColumn` to drop one column, or `dropColumns` to drop many:

```dart
await schema.table('users', (Table table) {
  table.dropColumn('age');
  table.dropColumns(<String>['a', 'b']);
});
```

There are also helpers for the helper columns. `dropTimestamps` drops `created_at` and `updated_at`, and `dropSoftDeletes` drops `deleted_at`:

```dart
table.dropTimestamps();

table.dropSoftDeletes();
```

## Indexes

### Creating indexes

Indexes make lookups fast. You can add one with a modifier on the column:

```dart
table.string('slug').unique();
```

To make an index on more than one column, call the index method on the table. It takes a column name or a list of names:

```dart
table.index(<String>['state', 'created_at']); // posts_state_created_at_index
table.unique('slug');                         // posts_slug_unique
table.primary(<String>['post_id', 'tag_id']); // composite primary key
```

Index names are `{table}_{columns}_{index|unique|foreign}`. To use your own name, give it as the last argument:

```dart
table.unique('slug', 'my_name');
```

### Full text indexes

If you want to search text, use `fullText`. On MySQL it makes a `FULLTEXT` index. On Postgres it makes a `gin` index on `to_tsvector('english', ...)`:

```dart
table.fullText('body'); // posts_body_fulltext
```

### Renaming indexes

Use `renameIndex` with the old and the new name:

```dart
table.renameIndex('posts_slug_unique', 'posts_url_unique');
```

### Dropping indexes

`dropIndex` and `dropUnique` take the columns or the index name:

```dart
table.dropIndex(<String>['state', 'created_at']); // by columns
table.dropUnique('posts_slug_unique');            // or by name
```

Use `dropPrimary` to drop the primary key. On Postgres it takes the name, and the default is `{table}_pkey`. MySQL needs no name:

```dart
table.dropPrimary();
```

### Checking an index

`hasIndex` takes an index name, or a list of its columns:

```dart
await schema.hasIndex('posts', 'posts_slug_unique');             // by name
await schema.hasIndex('posts', <String>['state', 'created_at']); // by columns
```

The list must have all the columns of the index, in the same order.

### Foreign keys

A foreign key makes sure a row only points to a parent row that exists. `foreignId` with `constrained` is the short way to make one:

```dart
table.foreignId('user_id').constrained().cascadeOnDelete();
```

It does the same as this longer form:

```dart
table.foreignId('user_id');
table.foreign('user_id').references('id').on('users').onDelete('cascade');
```

`constrained` guesses the table from the column name: `user_id` becomes `users`, and `category_id` becomes `categories`. Dox models use singular table names by default (`User` is `user`), so if your table is singular, give the name:

```dart
table.foreignId('user_id').constrained('user');
```

If the column can be `NULL`, put `nullable()` before `constrained()`:

```dart
table.foreignId('editor_id').nullable().constrained('users');
```

`foreignIdFor` makes the foreign key column of a model, like `user_id`. Then `constrained` points to the table and primary key of that model. Give a name as the second argument to change the column name:

```dart
table.foreignIdFor(User()).constrained().cascadeOnDelete();
```

`foreignIdFor` is always a big integer. For a model with a text key, use `foreignUuid` or `foreignUlid`.

!!! warning "Same type on both sides"
    `id()` and `foreignId()` are both big integers, so they match. If the parent uses `increments()` (a normal integer), use `unsignedInteger()` for the child on MySQL.

#### Foreign key actions

You can say what happens to the child rows when the parent is deleted or updated. Use `onDelete` and `onUpdate` with `'cascade'`, `'set null'`, `'restrict'` or `'no action'`:

```dart
table.foreign('user_id').references('id').on('users').onDelete('set null');
```

There are also short methods: `cascadeOnDelete()`, `nullOnDelete()`, `restrictOnDelete()`, `cascadeOnUpdate()`, `nullOnUpdate()` and `restrictOnUpdate()`.

#### Dropping foreign keys

`dropForeign` takes the columns or the key name:

```dart
table.dropForeign(<String>['user_id']);

table.dropForeign('posts_user_id_foreign');
```

`dropConstrainedForeignId` drops the foreign key and then the column:

```dart
table.dropConstrainedForeignId('user_id');
```

#### Turning foreign key checks off

Sometimes you must write rows before their parent rows, for example when you copy data. Use `withoutForeignKeyConstraints` for that work. It turns the checks on again after the function, also when it throws:

```dart
await schema.withoutForeignKeyConstraints(() async {
  // the post first, its user later
  await QueryBuilder.table('posts').insert(<String, dynamic>{'user_id': 1, 'title': 'Hi'});
  await QueryBuilder.table('users').insert(<String, dynamic>{'id': 1, 'name': 'Ann'});
});
```

On SQLite, run it outside a transaction. Postgres only waits for keys made `DEFERRABLE`, and Dox keys are not, so on Postgres the keys are still checked. See [Foreign key checks per database](#foreign-key-checks-per-database).

## Details

This section is for special cases. Most apps do not need it.

### Other column notes

- `softDeletesTz` is the same as `softDeletes`, because it is already a time with a zone.
- With the [`laravelPostgresTypes` flag](index.md#orm-flags), a new Postgres table gets `TIMESTAMP` for `timestamps()` and `softDeletes()`, and `JSON` for `json()`.
- MySQL only allows a default on `TEXT`, `BLOB` and `JSON` as an expression. The schema builder writes it as `DEFAULT ('value')` for you.
- `collation` on a non-text column throws an `ArgumentError`. Postgres and SQLite ignore it. Give it again in `.change()`.
- `unsigned`, `comment`, `after` and `useCurrentOnUpdate` are ignored on databases that do not support them. `after` adds the column at the end there.
- `change()` with `unique()` or `index()` adds the index. It fails when the index already exists.
- `change()` runs one `ALTER TABLE ... ALTER COLUMN ... TYPE ... USING col::type` on Postgres (with `SET/DROP NOT NULL`, `SET/DROP DEFAULT` and the enum `CHECK` again), `MODIFY COLUMN` on MySQL, and a table rebuild on SQLite.

### Index name rules

- The primary key is named `primary` on MySQL, MariaDB and SQLite. On Postgres it has its real name, like `posts_pkey`.
- `hasIndex` compares names like the database does. MySQL, MariaDB and SQLite ignore the case. Postgres needs the exact case.
- The longest index name is 63 characters on Postgres and 64 on MySQL. SQLite has no limit.

### Foreign key checks per database

`disableForeignKeyConstraints()` and `enableForeignKeyConstraints()` do the same as `withoutForeignKeyConstraints`, in two steps:

```dart
await QueryBuilder.transaction(() async {
  await schema.disableForeignKeyConstraints();
  // ...
  await schema.enableForeignKeyConstraints();
});
```

| Database | SQL | Limits |
|---|---|---|
| SQLite | `PRAGMA foreign_keys = OFF` | It is for the one connection of the isolate, so other code of that isolate is not checked either while it is off. Inside a transaction it does nothing. |
| MySQL, MariaDB | `SET FOREIGN_KEY_CHECKS = 0` | It is a setting of one pool connection, so `disable` and `enable` must run inside a transaction, else they throw a `StateError`. Turn the checks on again before the transaction ends. |
| Postgres | `SET CONSTRAINTS ALL DEFERRED` | Only keys made `DEFERRABLE` wait, and only until the checks are on again. It must run inside a transaction too. |

- On MySQL, MariaDB and Postgres, `withoutForeignKeyConstraints` runs in a transaction, so all its queries use the same connection. Inside another transaction it uses a savepoint.
- A migration runs in a transaction, so `disable` and `enable` work there on every database. On SQLite, a migration already runs with the checks off.

### SQLite notes

SQLite `ALTER TABLE` can only add, rename and drop columns. So for `change()`, for `foreign(...)` on an existing table and for `dropForeign(...)`, Dox makes the table again. It makes a new table with the change, copies the rows, drops the old table and renames the new one, all in one transaction. It keeps the columns, primary key, `AUTOINCREMENT`, foreign keys, indexes and enum checks. It fails on tables with other `CHECK` constraints or with generated columns.

Other SQLite limits:

- `primary(...)` on an existing table is not supported.
- `fullText` and `dropPrimary` throw an `UnsupportedError`.
- `renameIndex` drops the index and makes it again with the new name.
- A new `NOT NULL` column needs a default. A new column can not default to `CURRENT_TIMESTAMP`.
- `dropColumn` fails when the column is in an index or a foreign key. Drop those first.
- On MySQL and MariaDB, schema changes save right away and are not part of a transaction. On Postgres and SQLite they are.

### See the SQL

Every change is a `Table` blueprint. A grammar turns it into SQL without a database. The grammars are `PostgresGrammar`, `MysqlGrammar` and `SqliteGrammar`:

```dart
Table table = Table('users', creating: true)
  ..id()
  ..string('email').unique();
print(table.toSql(PostgresGrammar()));
// [CREATE TABLE "users" ("id" BIGSERIAL NOT NULL PRIMARY KEY, "email" VARCHAR(255) NOT NULL),
//  CREATE UNIQUE INDEX "users_email_unique" ON "users" ("email")]
```

On SQLite, the changes that need a table rebuild (and `renameIndex`) only run on a database.

## See also

- [Migration](migration.md): write and run migrations.

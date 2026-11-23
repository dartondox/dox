---
icon: lucide/table
---

# Schema builder

The schema builder creates, changes and drops tables with Dart code that works on Postgres, MySQL, MariaDB and SQLite.

## Setup

In a [migration](migration.md), `up` and `down` get a `Schema` on the migration connection:

```dart
await schema.create('posts', (Table table) {
  table.id();
  table.foreignId('user_id').constrained().cascadeOnDelete();
  table.string('title');
  table.text('body').nullable();
  table.timestamps();
});
```

Outside a migration, `Schema()` uses the query builder connection and flags. `Schema(driver, flags)` takes your own:

```dart
Schema schema = Schema();
await schema.dropIfExists('posts');
```

## Tables

### Creating tables

`create` makes a new table. The function adds the columns:

```dart
await schema.create('users', (Table table) {
  table.id();
  table.string('email');
});
```

### Updating tables

`table` changes a table that exists:

```dart
await schema.table('users', (Table table) {
  table.string('avatar').nullable();
});
```

### Renaming and dropping tables

`rename` renames a table. `drop` drops it, and `dropIfExists` does not fail when it is missing:

```dart
await schema.rename('posts', 'articles');
await schema.drop('users');
await schema.dropIfExists('users');
```

### Checking tables and columns

`hasTable`, `hasColumn` and `hasColumns` return true when the table or columns exist:

```dart
if (await schema.hasTable('users')) {
  // ...
}

await schema.hasColumn('users', 'email');
await schema.hasColumns('users', <String>['name', 'email']);
```

`getColumnListing` returns the column names of a table, in order:

```dart
List<String> columns = await schema.getColumnListing('users');
```

## Columns

### Available column types

Each column type is a method on `Table`:

| Method | Postgres | MySQL, MariaDB | SQLite |
|---|---|---|---|
| `id()`, `bigIncrements('id')` | BIGSERIAL PRIMARY KEY | BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY | INTEGER PRIMARY KEY AUTOINCREMENT |
| `increments('id')` | SERIAL PRIMARY KEY | INT UNSIGNED AUTO_INCREMENT PRIMARY KEY | INTEGER PRIMARY KEY AUTOINCREMENT |
| `string('c', [255])` | VARCHAR(n) | VARCHAR(n) | VARCHAR(n) |
| `char('c', [255])` | CHAR(n) | CHAR(n) | CHAR(n) |
| `text('c')` | TEXT | TEXT | TEXT |
| `mediumText('c')` | TEXT | MEDIUMTEXT | TEXT |
| `longText('c')` | TEXT | LONGTEXT | TEXT |
| `integer('c')` | INTEGER | INT | INTEGER |
| `bigInteger('c')` | BIGINT | BIGINT | INTEGER |
| `smallInteger('c')` | SMALLINT | SMALLINT | INTEGER |
| `tinyInteger('c')` | SMALLINT | TINYINT | INTEGER |
| `unsignedInteger('c')`, `unsignedBigInteger`, `unsignedSmallInteger`, `unsignedTinyInteger` | signed type | ... UNSIGNED | INTEGER |
| `float('c')` | REAL | FLOAT | FLOAT |
| `double('c')` | DOUBLE PRECISION | DOUBLE | DOUBLE |
| `decimal('c', [8], [2])` | DECIMAL(p, s) | DECIMAL(p, s) | DECIMAL(p, s) |
| `boolean('c')` | BOOLEAN | TINYINT(1) | BOOLEAN |
| `date('c')` | DATE | DATE | DATE |
| `dateTime('c')` | TIMESTAMP | DATETIME | DATETIME |
| `dateTimeTz('c')` | TIMESTAMPTZ | DATETIME | DATETIME |
| `time('c')` | TIME | TIME | TIME |
| `timestamp('c')` | TIMESTAMP | TIMESTAMP | TIMESTAMP |
| `timestampTz('c')` | TIMESTAMPTZ | TIMESTAMP | TIMESTAMP |
| `json('c')`, `jsonb('c')` | JSONB | JSON | JSON |
| `uuid(['uuid'])` | UUID | CHAR(36) | TEXT |
| `binary('c')` | BYTEA | BLOB | BLOB |
| `enumeration('c', ['a', 'b'])` | VARCHAR(255) + CHECK | ENUM('a', 'b') | VARCHAR(255) + CHECK |
| `foreignId('user_id')` | BIGINT | BIGINT UNSIGNED | INTEGER |
| `foreignUuid('user_id')` | UUID | CHAR(36) | TEXT |
| `foreignIdFor(User())` | BIGINT | BIGINT UNSIGNED | INTEGER |
| `ulid(['ulid'])`, `foreignUlid('user_id')` | CHAR(26) | CHAR(26) | CHAR(26) |
| `year('c')` | INTEGER | YEAR | INTEGER |
| `ipAddress(['ip_address'])` | VARCHAR(45) | VARCHAR(45) | VARCHAR(45) |

With the [`laravelPostgresTypes` flag](index.md#orm-flags), a new Postgres table gets TIMESTAMP and JSON in place of TIMESTAMPTZ and JSONB.

### Column helpers

`timestamps` adds nullable created_at and updated_at columns:

```dart
table.timestamps();
```

`softDeletes` adds a nullable deleted_at column, for models with `softDelete: true`. `softDeletesTz` is the same:

```dart
table.softDeletes();
```

`morphs` adds the columns of a [polymorphic relation](model/relationship/polymorphic.md): owner_id, owner_type and one index on both. `nullableMorphs` allows NULL, and `uuidMorphs` makes owner_id a uuid:

```dart
table.morphs('owner');
```

`rememberToken` adds a nullable remember_token column:

```dart
table.rememberToken();
```

### Column modifiers

Modifiers come after the column type:

```dart
table.string('email').nullable().unique();
```

| Modifier | What it does |
|---|---|
| `nullable()` | Allow NULL. Columns are NOT NULL by default. `nullable(false)` makes it NOT NULL again. |
| `defaultTo(value)` | Set a default value. Strings are escaped. A bool, a number, null, a map or list (as JSON) and a `DateTime` work too. `withDefault` is the same. |
| `defaultRaw('sql')` | Set the default as raw SQL, not escaped. Put an expression in brackets, like `defaultRaw('(1 + 1)')`. |
| `useCurrent()` | Default to the current time. |
| `useCurrentOnUpdate()` | Set the current time on each update. MySQL only. |
| `unique()` | Add a unique index `{table}_{column}_unique`. |
| `index()` | Add an index `{table}_{column}_index`. |
| `primary()` | Make the column the primary key. |
| `unsigned()` | UNSIGNED. MySQL only. |
| `comment('text')` | Add a column comment. Postgres and MySQL only. |
| `collation('utf8mb4_bin')` | Set the collation of a text column. MySQL and MariaDB only. |
| `after('column')` | Put the new column after another one. MySQL only, in `schema.table`. |
| `change()` | Change a column that exists. See [Modifying columns](#modifying-columns). |

Other databases ignore the MySQL only modifiers.

### Modifying columns

In `schema.table`, a column is added. To change a column that exists, add `.change()`:

```dart
await schema.table('posts', (Table table) {
  table.string('title', 500).nullable().defaultTo('x').change();
});
```

`change()` sets the full new column, so give every modifier you want to keep. A default you leave out is gone.

### Renaming columns

`renameColumn` renames a column:

```dart
await schema.table('users', (Table table) {
  table.renameColumn('bio', 'about');
});
```

### Dropping columns

`dropColumn` drops one column, and `dropColumns` drops many. `dropTimestamps` and `dropSoftDeletes` drop the helper columns:

```dart
await schema.table('users', (Table table) {
  table.dropColumn('age');
  table.dropColumns(<String>['a', 'b']);
  table.dropTimestamps();
  table.dropSoftDeletes();
});
```

## Indexes

### Creating indexes

`index`, `unique` and `primary` on the table take a column or a list of columns:

```dart
// posts_state_created_at_index
table.index(<String>['state', 'created_at']);
table.unique('slug'); // posts_slug_unique
table.primary(<String>['post_id', 'tag_id']); // composite primary key
```

The last argument sets your own name, like `table.unique('slug', 'my_name')`. `indexName` gives the default name: `table.indexName('unique', ['slug'])`.

### Full text indexes

`fullText` makes a FULLTEXT index on MySQL, and a gin index on `to_tsvector('english', ...)` on Postgres:

```dart
table.fullText('body'); // posts_body_fulltext
```

### Renaming indexes

`renameIndex` takes the old and the new name:

```dart
table.renameIndex('posts_slug_unique', 'posts_url_unique');
```

### Dropping indexes

`dropIndex` and `dropUnique` take the columns or the index name:

```dart
table.dropIndex(<String>['state', 'created_at']);
table.dropUnique('posts_slug_unique');
```

`dropPrimary` drops the primary key. On Postgres it takes the name, `{table}_pkey` by default:

```dart
table.dropPrimary();
```

### Checking an index

`hasIndex` takes an index name, or all its columns in order:

```dart
await schema.hasIndex('posts', 'posts_slug_unique');
await schema.hasIndex('posts', <String>['state', 'created_at']);
```

On MySQL, MariaDB and SQLite, the primary key is named primary.

## Foreign keys

### Creating foreign keys

`foreignId` with `constrained` makes the column and the key:

```dart
table.foreignId('user_id').constrained().cascadeOnDelete();
```

It is the same as this long form:

```dart
table.foreignId('user_id');
table.foreign('user_id').references('id').on('users').onDelete('cascade');
```

`constrained` guesses the table from the column: user_id gives users. Dox models use singular table names by default, so give the name if your table is singular:

```dart
table.foreignId('user_id').constrained('user');
table.foreignId('editor_id').nullable().constrained('users');
```

Put `nullable()` before `constrained()`. The second argument of `constrained` is the parent column, id by default. `foreignId('user_id').references('id').on('users')` also works.

### Foreign keys for a model

`foreignIdFor` makes the foreign key column of a model, like user_id. Then `constrained` uses the table and key of that model:

```dart
table.foreignIdFor(User()).constrained().cascadeOnDelete();
```

A second argument sets the column name. `foreignIdFor` is always a big integer, so for a text key use `foreignUuid` or `foreignUlid`.

!!! warning "Same type on both sides"
    `id()` and `foreignId()` are both big integers. If the parent uses `increments()`, use `unsignedInteger()` for the child on MySQL.

### Foreign key actions

`onDelete` and `onUpdate` take cascade, set null, restrict or no action:

```dart
table.foreign('user_id').references('id').on('users').onDelete('set null');
```

The short forms are `cascadeOnDelete()`, `nullOnDelete()`, `restrictOnDelete()`, `cascadeOnUpdate()`, `nullOnUpdate()` and `restrictOnUpdate()`.

### Dropping foreign keys

`dropForeign` takes the columns or the key name. `dropConstrainedForeignId` drops the key and then the column:

```dart
table.dropForeign(<String>['user_id']);
table.dropForeign('posts_user_id_foreign');
table.dropConstrainedForeignId('user_id');
```

### Turning foreign key checks off

`withoutForeignKeyConstraints` turns the checks off for the function, and on again after it:

```dart
await schema.withoutForeignKeyConstraints(() async {
  await QueryBuilder.table('posts')
      .insert(<String, dynamic>{'user_id': 1, 'title': 'Hi'});
  await QueryBuilder.table('users')
      .insert(<String, dynamic>{'id': 1, 'name': 'Ann'});
});
```

On SQLite, run it outside a transaction. On Postgres, only DEFERRABLE keys wait, and Dox keys are not DEFERRABLE.

`disableForeignKeyConstraints` and `enableForeignKeyConstraints` do the same in two steps. On MySQL, MariaDB and Postgres, run them in a transaction, or they throw a `StateError`:

```dart
await QueryBuilder.transaction(() async {
  await schema.disableForeignKeyConstraints();
  // ...
  await schema.enableForeignKeyConstraints();
});
```

## SQLite notes

SQLite ALTER TABLE can only add, rename and drop columns. For `change()`, `foreign(...)` on a table that exists and `dropForeign(...)`, Dox makes the table again in one transaction. This fails on a table with other CHECK rules or with generated columns.

- `primary(...)` on a table that exists does not work.
- `fullText` and `dropPrimary` throw an `UnsupportedError`.
- A new NOT NULL column needs a default, and a new column can not default to CURRENT_TIMESTAMP.
- `dropColumn` fails when the column is in an index or a foreign key. Drop those first.

## See the SQL

A `Table` is a blueprint. `toSql` turns it into SQL with a grammar: `PostgresGrammar`, `MysqlGrammar` or `SqliteGrammar`:

```dart
Table table = Table('users', creating: true)
  ..id()
  ..string('email').unique();
print(table.toSql(PostgresGrammar()));
// [CREATE TABLE "users" (...),
//  CREATE UNIQUE INDEX "users_email_unique" ...]
```

`schema.build(table)` runs the SQL of a blueprint.

## Next steps

- [Migration](migration.md): write and run migrations.
- [Model](model/index.md): the class for each table.

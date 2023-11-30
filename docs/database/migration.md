# Migration

## Create migration

=== "Default (SQL)"

    ```py
    dox create:migration create_blog_table
    ```

=== "SQL"

    ```py
    dox create:migration create_blog_table --sql
    ```

=== "Dart"

    ```py
    dox create:migration create_blog_table --dart
    ```

!!! info
    This command will produce a migration file within the `db/migration` directory. In this file, you can make changes to your schema, including creating, updating, or deleting tables.

!!! tip
    Starting from version `1.1` of the dox-cli, it will automatically generate a `SQL` file by default. This approach is 10x faster than using the `--dart` option and does not necessitate a Dart runtime environment in production.

## Run migration

=== "Command"

    ```py
    dox migrate
    ```

!!! info
    Please make sure that you have created `.env` file with with below variable names to run migration.

```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USERNAME=admin
DB_PASSWORD=password
```

## Rollback migration

=== "Command"

    ```py
    dox migrate:rollback
    ```
## With `.sql` example

```py
-- up
CREATE TABLE IF NOT EXISTS blog (
    id serial PRIMARY KEY,
	user_id int NOT NULL,
	title VARCHAR ( 255 ) NOT NULL,
	slug VARCHAR ( 255 ) NOT NULL,
	description TEXT,
	deleted_at TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP 
)

-- down
DROP TABLE IF EXISTS blog 
```

!!! info
    Employ `--up` and `--down` to differentiate the migration scripts for upward and downward actions.


## With `.dart` example

### Create table

=== "Example"

    ```dart
    await Schema.create('blog', (Table table) {
        table.id();
        table.string('slug').unique();
        table.string('title').nullable();
        table.string('body').nullable();
        table.timestamps();
    });
    ```

!!! info
    Dox adheres to singular table naming conventions, but you can still employ custom table names in your model. For additional details, please refer to [custom table name in model](model/index.md/#doxmodel-options).


### Update table

=== "Example"

    ```dart
    await Schema.table('blog', (Table table) {
        // drop/delete amount column
        table.dropColumn('amount');
        
        // rename title to blog_title
        table.renameColumn('title', 'blog_title');
        
        // newly rename blog_title to nullable
        table.string('blog_title').nullable(); 
        
        // change slug to nullable
        table.string('slug').unique().nullable(); 
        
        // add new colum column1
        table.string('column1').nullable(); 
        
        // add new colum column2
        table.string('column2').nullable(); 
    });
    ```

### Drop table

=== "Example"

    ```dart
    await Schema.drop('blog');
    ```

### Drop column


=== "Example"

    ```dart
    await Schema.table('blog', (Table table) {
        table.dropColumn('amount');
    });
    ```

### Rename column


=== "Example"

    ```dart
    await Schema.table('blog', (Table table) {
        table.renameColumn('old_name', 'new_name');
    });
    ```

### Data types

| Command                           | Description                                          |
| --------------------------------- | ---------------------------------------------------- |
| `table.id()`                      | Incrementing ID                                      |
| `table.string('title')`           | VARCHAR equivalent column                            |
| `table.text('description')`       | TEXT equivalent column                               |
| `table.uuid('uuid')`              | UUID equivalent column                               |
| `table.integer('amount')`         | Integer equivalent column                            |
| `table.bigInteger('amount')`      | BIGINT equivalent column                             |
| `table.char('status')`            | CHAR equivalent column                               |
| `table.money('price')`            | MONEY equivalent column                              |
| `table.json('price')`             | JSON equivalent column                               |
| `table.jsonb('price')`            | JSONB equivalent column                              |
| `table.decimal('price', 11, 2)`   | DECIMAL equivalent column with a precision and scale |
| `table.float4('price')`           | FLOAT4 equivalent column                             |
| `table.float8('price')`           | FLOAT8 equivalent column                             |
| `table.timestamp('approved_at')`  | TIMESTAMP equivalent column                          |
| `table.date('dob')`               | DATE equivalent column                               |
| `table.time('active_time')`       | TIME equivalent column                               |
| `table.timestampTz('created_at')` | TIMESTAMPTZ equivalent column                        |
| `table.softDeletes()`             | Adds **deleted\_at** column                          |
| `table.timestamps()`              | Adds **created\_at** and **updated\_at** columns     |

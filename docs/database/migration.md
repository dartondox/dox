# Migration

## Create migration

=== "Create migration file"

    ```py
    dox create:migration create_blog_table
    ```

!!! info
    This command will produce a migration file within the `db/migration` directory. In this file, you can make changes to your schema, including creating, updating, or deleting tables.


## Run migration

=== "Command"

    ```py
    dox migration:run
    ```

!!! info
    `dox migrate` is a short name for the same command.

!!! info
    Please make sure that you have created `.env` file with with below variable names to run migration.

```bash
DB_CONNECTION=postgres # or mysql
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USERNAME=admin
DB_PASSWORD=password
```

!!! info
    `DB_CONNECTION` can be `postgres` or `mysql`. The default is `postgres`.
    The default port is `5432` for postgres and `3306` for mysql.
    On MySQL, statements like `CREATE`, `ALTER` and `DROP` save right away.
    So if a migration fails half way, these changes are not undone.

## Rollback migration

Rollback undoes the last batch. A batch is the group of migrations that ran in one `migration:run`.
Migrations are undone newest first.

=== "Last batch"

    ```py
    dox migration:rollback
    ```

=== "Last 2 migrations"

    ```py
    dox migration:rollback --step=2
    ```

=== "All migrations"

    ```py
    dox migration:reset
    ```

=== "All, then run again"

    ```py
    dox migration:refresh
    ```

!!! info
    `migrate:rollback`, `migrate:reset` and `migrate:refresh` are short names for the same commands.

## Example

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
    Put the `up` sql under a line `-- up`, and the `down` sql under a line `-- down`.
    Each of these lines must be on its own line.
    Other `--` lines are normal sql comments.

!!! info
    Statements are split on `;`.
    A `;` inside quotes, comments or a postgres `$$ ... $$` body does not split.

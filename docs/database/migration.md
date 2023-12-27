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
    Employ `--up` and `--down` to differentiate the migration scripts for upward and downward actions.

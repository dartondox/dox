## 3.0.0-alpha.11

- Version bump only, to match the other packages.

## 3.0.0-alpha.10

- Version bump only, to match the other packages.

## 3.0.0-alpha.9

- New `Seeder` and `SeederRunner`. A seeder puts data in the database. `call()` runs other seeders. `SeederRunner(seeders: seeders).run(args)` runs `DatabaseSeeder`, or another one with `--class=<name>`, in one transaction. It reads the database from `.env`, the same as the migrations.
- New `Migrator.fresh()` and the `fresh` command of `Migrator.run()`. It drops every table of the database, then runs all migrations.

## 3.0.0-alpha.8

- A migration that runs inside a transaction you already opened (eg. with `Migrator(connection: ...)`) now uses a savepoint. A failed migration undoes only its own work.

## 3.0.0-alpha.7

- Breaking: migrations run on the dox_orm drivers: the native Postgres and MySQL drivers, and SQLite. The `postgres` and `mysql_dart` packages are gone. When the native library does not load, the migration stops with an error that says why.
- Breaking: `Migrator(connection: ...)` takes a dox_orm `DBDriver` now, eg. `SqlQueryBuilder().dbDriver`. The migrator does not close it. New `Migrator(config: ...)` takes a `ConnectionConfig`, eg. `databaseConfig.getConnectionConfig()`, and closes it at the end.
- TLS works the same as dox_orm. For Postgres, `sslmode=require` encrypts and `verify-full` also checks the certificate. For MySQL the certificate is checked. Add `verifyCertificate=false` to `DATABASE_URL` to skip the MySQL check in development.

## 3.0.0-alpha.6

- A `DB_HOST` that starts with `/` is a MySQL Unix socket file too (Postgres: the socket folder). `?socket=/path` works in a `mysql://` `DATABASE_URL`.

## 3.0.0-alpha.5

- `DATABASE_URL` support. When it is set, it wins over `DB_CONNECTION` and the other `DB_*` keys. Its `sslmode` (Postgres) or `ssl` (MySQL) option turns TLS on.
- A `DB_HOST` that starts with `/` is a Postgres Unix socket folder, like `/cloudsql/project:region:instance` on Cloud Run.
- Migrations read real environment variables too. Before, a `.env` file hid them. Now a real env var wins over `.env`, the same as `Env.get()` of dox_core. An empty value, or `null`, counts as missing.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Version bump only, to match the other packages.

## 3.0.0-alpha.2

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- `sqlite3` 3 (SQLite is bundled, no system library needed).

## 3.0.0-alpha.1

- Removed the `dox_migration` executable from pubspec (its script was removed before). Use the `dox` CLI.
- Added SQLite: `DB_CONNECTION=sqlite` and `DB_DATABASE=<file path>`.
- MySQL driver is now `mysql_dart` (was `mysql1`). The MySQL 8 default login (`caching_sha2_password`) works.
- `migrate()` and the other commands also take a pool (postgres `Pool`, mysql `MySQLConnectionPool`). Each file runs in one transaction on one connection.
- Breaking: a passed mysql connection must be a `mysql_dart` `MySQLConnection` or `MySQLConnectionPool` (not `mysql1`).
- Needs Dart 3.6 or newer.

## 3.0.0

- Support MySQL. Set `DB_CONNECTION=mysql` in `.env` (default is `postgres`)
- Run each statement of a `.sql` migration one by one, inside a transaction
- Rollback undoes only the last batch, newest first. Add `step`, `reset()` and `refresh()`
- Stop at the first failed migration
- Fix `.sql` parsing: a `-` in the sql no longer cuts the `up` or `down` part
- Fix statement split: `;` inside quotes, comments or `$$` bodies does not split

## 2.0.0

- Release stable version v2.0

## 2.0.0-alpha.2

- Remove .dart option

## 1.0.4

- Improve loading .env

## 1.0.3

- Bug fixed on sql rollback

## 1.0.2

- Fixed rollback issues

## 1.0.1

- Close connection when running from cli

## 1.0.0

- Initial version.

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

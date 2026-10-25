## 3.0.0-alpha.11

- `dox build` also builds `bin/queue.dart` and `bin/schedule.dart` when they exist, to `build/bundle/bin/queue` and `build/bundle/bin/schedule`. Before, the worker and the scheduler had no production binary.
- Fix: `dox build` copied the local SQLite database (`db/dox.sqlite`, with its `-wal` and `-shm` files) into `build/bundle/db`, so dev data went to production. SQLite files are now left out.
- `dox --help` and `dox -h` show the help, like `dox help`.

## 3.0.0-alpha.10

- `make:*` is now the main name of every generator: `make:controller`, `make:middleware`, `make:dto`, `make:serializer` and `make:model`, like `make:migration`, `make:factory` and `make:seeder`. The `create:*` names still work as aliases.
- New `dox make:job <name>`: makes `lib/app/jobs/<name>.job.dart` and `bin/queue.dart` when it is missing. It prints a hint to add `dox_queue` and to run `build_runner`.
- New `dox queue:work`, `queue:failed`, `queue:retry`, `queue:forget` and `queue:flush`: run `bin/queue.dart` with the same flags.
- New `dox schedule:work`, `schedule:run`, `schedule:list` and `schedule:test <name>`: run `bin/schedule.dart`.
- These commands pass the terminal through, send SIGINT and SIGTERM to the app script so a worker can stop by itself, and return its exit code. When the script is missing they print how to set it up.

## 3.0.0-alpha.9

- `dox make:controller` (`create:controller`) writes `@Inject()` above the class, and no global controller instance. The file shows the typed route to use. The command says to run `build_runner`.
- New `dox make:factory <model>`: makes `db/factories/<model>.factory.dart`.
- New `dox make:seeder <name>`: makes `db/seeders/<name>.seeder.dart`, writes the seeder list `db/seeders/seeders.dart` and makes `bin/seed.dart` when it is missing.
- New `dox db:seed [--class=<name>]`: runs `bin/seed.dart`. The default seeder is `DatabaseSeeder`.
- New `dox migration:fresh` (or `migrate:fresh`): drops all tables, then runs all migrations.
- `--seed` after `migration:run`, `migration:refresh` or `migration:fresh` runs the seeders when the migrations end well.

## 3.0.0-alpha.8

- Version bump only, to match the other packages.

## 3.0.0-alpha.7

- Breaking: `create:controller` no longer takes `-ws`. Dox uses Socket.IO for realtime now. See the Socket.IO docs for a namespace class.
- Security: `dox create` now copies `.env.example` to `.env` and writes a new random `APP_KEY`. Before, every new app used the same public key from the template. You no longer run `cp .env.example .env`.
- The `.env.example` of the CLI has an empty `APP_KEY`. Run `dox key:generate` to set one.

## 3.0.0-alpha.6

- Fix: `dox key:generate` dropped `.env` lines with more than one `=` (like `DATABASE_URL=postgres://u:p@h/db?sslmode=require`). It also dropped comment lines. Now it only changes the `APP_KEY` line. Every other line stays as it is.
- Fix: `dox create` crashed with `Failed to decode data using encoding 'utf-8'` when the template had a binary file (for example `db/dox.sqlite-shm`). It now skips files that are not UTF-8 text. It only writes a file when its content changes.

## 3.0.0-alpha.5

- Fix: `dox create my_app` without `--version` crashed with a `RangeError`.
- Fix: `dox create` picked the GitHub "latest" template release, which skips pre-releases. During the 3.x alpha that gave the old 2.x template. It now takes the newest template with the same major version as the CLI.
- Fix: `dox env:generate` read `KEY=3000 # note` as text, not as an `int`. A `#` after a space is now a comment.
- Fix: `dox update` ran a plain `dart pub global activate dox`, which skips pre-releases. During the 3.x alpha it installed the old 2.x CLI. It now installs the newest version with the same major version as the CLI, from the pub.dev version list.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Version bump only, to match the other packages.

## 3.0.0-alpha.2

- Fix: `dox build` no longer passes `--delete-conflicting-outputs` to build_runner (it was removed and printed a warning).
- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- `dox build` now runs `dart build cli` (AOT, with build hooks). The output is `build/bundle/`. Start it with `cd build/bundle && ./bin/server`.
- New `dox create:dto <name>`: makes `lib/app/http/dtos/<name>.dto.dart`. `dox create:request` is removed.
- `dox create:controller -r` uses `int id` for the resource methods.
- New `dox openapi:generate [dir]`. It runs the app's `bin/openapi.dart` and writes `openapi.json` and `openapi.yaml` (default `storage/openapi`).
- New `dox env:generate`: makes `lib/config/env.dart` (the typed env class) from `.env.example`.
- New `dox env:check`: loads the typed env and prints every missing or bad key (exit code 1).


## 3.0.0-alpha.1

- Version 3 of Dox. All Dox packages now share one version.
- Needs Dart 3.6 or newer.
- See the [release notes](https://github.com/dartondox/dox/pull/112) for all main changes.
- Generated models import `package:dox_orm/dox_orm.dart`.

## 2.0.1

- bug fix on dox create command

## 2.0.0

- Release stable version v2.0

## 2.0.0-alpha.3

- Fix migration issue

## 2.0.0-alpha.2

- Add option to create project with specific version

## 2.0.0-alpha.1

- Compatible with core version 2

## 1.1.1

- handle migration with dox_migration
- set default migration file with .sql

## 1.0.55

- Add command to create serializer
- Add help option

## 1.0.54

- update request template
- Add help option

## 1.0.53

- Added command to create form request `dox create:request Blog`

## 1.0.52

- Added command to create websocket controller

## 1.0.51

- Initial version.

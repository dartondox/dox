## Unreleased

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

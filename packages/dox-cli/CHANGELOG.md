## Unreleased

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- `dox build` now runs `dart build cli` (AOT, with build hooks). The output is `build/bundle/`. Start it with `cd build/bundle && ./bin/server`.
- New `dox create:dto <name>`: makes `lib/app/http/dtos/<name>.dto.dart`. `dox create:request` is removed.
- `dox create:controller -r` uses `int id` for the resource methods.
- New `dox openapi:generate [dir]`. It runs the app's `bin/openapi.dart` and writes `openapi.json` and `openapi.yaml` (default `storage/openapi`).


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

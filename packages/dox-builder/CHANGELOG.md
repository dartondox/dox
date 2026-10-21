## Unreleased

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- New builder `dox_builder:openapi`. It writes `lib/openapi.g.dart` with the OpenAPI docs of the app: it reads the `Route.*` calls, the controllers, the `@Dto` classes and the models. It writes nothing when the package has no controllers.
- `DtoJsonSchema`, `ModelSchema` and `JsonSchemaReader`: the JSON Schema of a `@Dto` class, a model or any Dart type. Other builders can use them.
- New: the DTO generator. For each `@Dto` class it writes `$<Name>Dto` (a `const DtoSchema<Name>`) into the `.g.dart` part: plain `if` checks per field, the converter, `fromMap`, `toMap` and the JSON Schema. It stops the build with a clear error for a bad DTO (a field that is not final, a type that is not supported, a rule that does not fit, a bad regex, ...).
- New builder `dox_builder:dtos`. It writes `lib/dtos.g.dart` with every DTO of the app, for `AppConfig(dtos: dtos)`. Two DTOs with the same name stop the build.
- `DtoReader`: the one place that knows DTO keys. The OpenAPI docs use the same keys as the DTO (snake_case by default, `@Name`, `@Dto(keyCase:)`).
- OpenAPI: `@Regex` (was `@Pattern`). `@Format` is removed. Form requests are removed.
- Fix: the OpenAPI route list has the full path, with the `Router` prefix and `Route.group()` prefixes. Two `'/'` routes in two groups now each get their docs.
- OpenAPI path params: every positional argument that is not the request and not a DTO.

## 3.0.0-alpha.1

- Version 3 of Dox. All Dox packages now share one version.
- Needs Dart 3.6 or newer.
- See the [release notes](https://github.com/dartondox/dox/pull/112) for all main changes.
- Works with analyzer 5 and 6.

## 2.0.0

- Bug fix on the builder

## 1.0.4

- Change `newQuery` to `query()` and deprecate `newQuery`
- Bug fix on `save()`

## 1.0.3

- Bug fixed on eager/preload data missing in `toMap` response.
- Auto convert camelCase variable into snake_case column.

## 1.0.2

- Bug fixed .dox_model_generator.g.part  from .dart which is not specified

## 1.0.1

- Bug fixed on soft deletes and custom table name

## 1.0.0

- Dox Builder

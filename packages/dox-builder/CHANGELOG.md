## Unreleased

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- New builder `dox_builder:openapi`. It writes `lib/openapi.g.dart` with the OpenAPI docs of the app: it reads the `Route.*` calls, the controllers, the `@Dto` classes and the models. It writes nothing when the package has no controllers.
- `DtoSchema`, `ModelSchema` and `JsonSchemaReader`: the JSON Schema of a `@Dto` class, a model or any Dart type. Other builders can use them.
- New: `@DoxEnv()` classes get `_$<Class>` in the `.g.dart` part. Each getter is read from the env once, converted to its type (String, int, double, num, bool, Uri, Duration, enum, List<String>) and kept in a final field. A getter body is the default. A nullable getter is optional. `load()` throws one `EnvException` with every missing or bad key.

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

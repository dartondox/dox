## Unreleased

- New: `lib/container.g.dart` builder. It finds every `@Inject()` class, every class that extends `Router`, every class that implements `DoxService` and every `@DoxModel` in `lib/`. It writes `registerContainer(IocContainer c)`, which makes each class with its constructor. Constructor parameters come from the container by type. Optional parameters that the container can not give keep their default. Required nullable ones get `null`.
- The build stops with a clear message for a required parameter the container can not give, for a dependency cycle (it shows the chain, like `A -> B -> A`), and for an abstract or generic `@Inject()` class. Two classes with the same name work: every import has a prefix.
- OpenAPI: typed routes (`Route.get<C>(path, (C c) => c.method)`) and `Route.resource(path, ControllerClass)` are read too.
- Generates the query scopes: an extension with one method for each `@Scope()` method, and `globalScopes` for `@Scope(global: true)`.
- Generates the column casts: `fromMap()` and `columnsToMap()` use the `cast` of `@Column()`. `bool` and enum fields get a cast without `cast`.
- Run `dart run build_runner build` to get the new code.

## 3.0.0-alpha.8

- Version bump only, to match the other packages.

## 3.0.0-alpha.7

- The generated `fromMap()` takes a `DateTime` from the driver as it is. It only parses a string.
- New generated `columnsToMap()` with the columns only. `convertToMap()` adds the relations to it.
- Models with no `beforeGet` hook get `readsRowDates => true`, so their rows skip the date to string step. A `beforeGet` hook still gets dates as strings.
- `tableColumns`, `preloadList`, `timestampsColumn` and the relation matchers are `const`, so no new list or map is made on each call.
- Run `dart run build_runner build` to get the new code.

## 3.0.0-alpha.6

- Version bump only, to match the other packages.

## 3.0.0-alpha.5

- `@DoxModel(timestamps: false)` makes a model without `createdAt` and `updatedAt`. `createdAt: null` or `updatedAt: null` turns off only one.
- The primary key field has the type of `@DoxModel(primaryKeyType: ...)`. It was always `int?`. The default is still `int`. The OpenAPI model schema uses the same type.
- Fix: a preloaded relation with a two word name (like `userInfo`) was missing from `toJson()`. The generator looked for `user_info` in the preload list, but the list has `userInfo`.
- Fix: the OpenAPI route scanner now puts one `/` between a group and a route path, like the router does.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Version bump only, to match the other packages.

## 3.0.0-alpha.2

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

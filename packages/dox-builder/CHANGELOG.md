## Unreleased

- Fix: `reload()` and preload now set a nullable `@HasOne`, `@BelongsTo`, `@MorphOne` or `@MorphTo` field to null when the related row is gone. Before, the field kept its old value. Run `build_runner` to get the new code.
- Fix: `reload()` and preload now set a `@HasMany`, `@ManyToMany` or `@MorphMany` field to an empty list when there are no related rows. Before, the field kept its old list. Run `build_runner` to get the new code.
- Note: a nullable list relation, like `List<Tag>? tags`, is now `[]` (not `null`) after a preload with no rows.
- DTOs: `@RequiredIf('type', 'company')` and `@RequiredWith(['phone'])` from `dox_validation`. The field is required only when the condition is true. Use them on a nullable field, a `Maybe` field or a field with a default. On an always-required field the build stops with a clear error.
- DTOs: the build stops when `@RequiredIf`, `@RequiredWith`, `@Same` or `@Confirmed(other:)` names a Dart field (like `accountType`) instead of its input key (`account_type`). The check would never match. It also stops for a `@DateFormatted` format with a letter it does not know.
- DTOs: in a `@Dto(strict: true)` class, the key that `@Confirmed` reads (like `password_confirmation`) is not an unknown key.
- New: DTO file rules `@MinSize('10KB')`, `@MimeTypes(['image/png', 'image/*'])` and `@Dimensions(minWidth:, maxWidth:, minHeight:, maxHeight:, width:, height:, ratio:)`. They need the next dox_validation release. A bad size or a `@Dimensions()` with no limit stops the build.
- New: `@ManyToMany(withPivot: [...], withTimestamps: true)` is passed to the ORM, so the relation reads the extra pivot columns. Needs the dox_orm version with many to many writes.
- New: the model builder makes the code for `@MorphMany`, `@MorphOne` and `@MorphTo` (polymorphic relations). A `@MorphTo` field has no model: its type is the field type, like `Model<dynamic>`, and its morph name is the field name in snake_case. The OpenAPI model schema has these relation keys too. Needs the dox_orm version with polymorphic relations.

## 3.0.2

- **Breaking: column and JSON keys can change.** Please read this before you update.
  - Digits are no longer split off. Before, `address2` gave the key `address_2`. Now it gives `address2`.
  - A name you give is used exactly as written. Before, `@Column(name: 'userID')` gave `user_i_d`. Now it gives `userID`. The same is true for `@Computed(name:)`, and for `primaryKey`, `createdAt` and `updatedAt` in `@DoxModel`.
  - DTO input keys change the same way: a field `line2` now reads the key `line2`, not `line_2`.
  - What to do: run `build_runner` and look for changed keys in the generated files. Then rename the column in a migration. Or keep the old key with `@Column(name: 'address_2')` (or `@Name('line_2')` on a DTO field).
- Fix: types from an import with a prefix (`import 'other.dart' as o;`) keep the prefix in the generated code, like `o.Role`, `List<o.Role>`, `EnumCast(o.Role.values)` and `o.$InnerDto`. Before, the code did not compile. This works in models, DTOs, env classes and scopes.
- Fix: `@Column(cast: ...)` now works for a model in a `part` file. The cast is read from the AST of the field.
- Fix: table names, column keys and relation keys are escaped in the generated code (`\`, `'` and `$`).
- Fix: a private class (like `_AdminRouter` or `@Inject() class _Cache`) is no longer put in `container.g.dart`, where it did not compile. The build shows a warning with the class and file.
- Fix: container errors now show the file and line of the problem.
- New: a constructor parameter of an abstract type gets the one container class that implements it. When two or more classes implement it, the build stops and names them.
- Fix: the OpenAPI builder reads the files in path order, so `openapi.g.dart` does not change between builds.
- Fix: the OpenAPI builder finds routes with a prefixed dox_core import, like `dox.Route.get(...)`. Only the `Route` class of dox_core counts.
- Fix: the OpenAPI builder stops with a clear error when two controllers, two `@Security` classes or two schema classes have the same name in two files. Before, one silently replaced the other. Dox finds them by name at runtime, so a new name would not match. Rename one of them.
- Fix: OpenAPI annotations count only when they come from a Dox package (`package:dox_...`). An app class with the same name, like `Summary`, is no longer read as one.
- Faster builds: the container, DTO list and OpenAPI builders skip `.g.dart` files. They also look at the text of a file first, and only resolve it when it can hold what they look for.
- Change: the model, DTO and env builder runs on `lib/` only by default. Before, it also ran on `test/`, `bin/` and `tool/`. A package with models or DTOs in `test/` adds this to its `build.yaml`:

    ```yaml
    targets:
      $default:
        builders:
          dox_builder:
            generate_for: ["lib/**", "test/**"]
    ```

## 3.0.1

- Version bump only, to match the other packages.

## 3.0.0

- The first stable release.

## 3.0.0-rc.1

- `lib/generated/dtos.g.dart` is now written for every app, also with no `@Dto`. The list is empty then. So the app can always have `dtos: dtos` in `AppConfig`. An app here is a package that imports `AppConfig` (from dox_core). Other packages with no DTO still get no file. The empty list is `final`, not `const`, so `dtos: dtos` does not trigger the `avoid_redundant_argument_values` lint.

## 3.0.0-alpha.17

- New: models get `setColumnValue(column, value)`. It sets a field by its column name, and returns false when the value is not of the field type. `model.increment()` and `model.decrement()` of dox_orm use it to set the field. The generated code needs the dox_orm that has `Model.setColumnValue()`. Run build_runner again after you update.

## 3.0.0-alpha.16

- Version bump only, to match the other packages.

## 3.0.0-alpha.15

- Change: the container builder finds every class that extends `DoxProvider` and writes `c.provider<...>` for it.

## 3.0.0-alpha.14

- New: the openapi builder reads `@Security` on middleware classes and writes them to `OpenApiRegistry.security`.

## 3.0.0-alpha.13

- Version bump only, to match the other packages.

## 3.0.0-alpha.12

- Fix: a route inside `Route.group('/web-auth', registerWebAuth)` lost the group prefix when the callback was a method or function, not a closure. The builder now reads that method with the prefix, also for nested groups. The route call in `openapi.g.dart` now has the full path, like `/web-auth/login`.

## 3.0.0-alpha.11

- Version bump only, to match the other packages.

## 3.0.0-alpha.10

- The app-wide files are now written to `lib/generated/`: `lib/generated/container.g.dart`, `lib/generated/dtos.g.dart` and `lib/generated/openapi.g.dart`. This keeps them out of the top of `lib/`. Import them from `package:<app>/generated/...`. Delete the old files in `lib/` after you run `dart run build_runner build`.
- Model part files (like `user.model.g.dart`) still sit next to their source file.

## 3.0.0-alpha.9

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

---
icon: lucide/list-checks
---

# Validation

`dox_validation` checks input and gives you typed Dart objects.

It has two parts:

1. **DTOs**: a class with `@Dto()` and rule annotations. A generator writes the checks. Use this for almost everything. See [DTOs](../the-basic/dto.md).
2. **Fluent schemas**: `v.object(...)`. Use them only when you know the shape of the input at runtime, not when you write the code.

Both give all errors at once, and both give a JSON Schema for [OpenAPI](openapi.md).

## Setup

`dox_core` uses `dox_validation` and exports it, so there is nothing to install. `import 'package:dox_core/dox_core.dart'` is all you need.

1. Make a DTO with `dox make:dto CreateUser`. It writes `lib/app/dtos/create_user/create_user.dto.dart`.
2. Run the generator: `dox build_runner:build`.
3. Give the list of DTOs to the app, once:

```dart title="lib/config/app.dart"
import 'package:my_app/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  // ...
  dtos: dtos, // from lib/generated/dtos.g.dart
);
```

Then ask for the DTO in a controller. Dox checks the body before the method runs. Bad input gets `422` with the errors:

```dart title="lib/app/http/controllers/user.controller.dart"
class UserController {
  Future<Map<String, dynamic>> store(CreateUser body) async {
    // body is already checked and typed
    return <String, dynamic>{'name': body.name};
  }
}
```

The full guide is at [Validation](../the-basic/validation.md). Every rule is in the [rules reference](../the-basic/validation-rules.md). The rest of this page is about the package itself.

## Defining a DTO

A DTO is a class with `@Dto()`. Each field gets its rules as annotations:

```dart
import 'package:dox_validation/dox_validation.dart';

part 'create_user.dto.g.dart';

@Dto()
class CreateUser {
  @Length(min: 3, max: 50)
  @Trim()
  final String name;

  @Email()
  final String email;

  const CreateUser({required this.name, required this.email});

  static const DtoSchema<CreateUser> schema = $CreateUserDto;
}
```

For each `@Dto` class, the generator writes a `const` `DtoSchema<CreateUser>` named `$CreateUserDto`. It holds the checks, the converter and the JSON Schema. The `static const schema` line lets you reach it as `CreateUser.schema`.

The generator also writes `lib/generated/dtos.g.dart`, with a list `dtos` of every DTO in `lib/`. Dox uses it to find a DTO by its type.

## Validating a map

`DtoSchema<T>` is also a normal `Schema<T>`. So you can use it inside `v.object(...)` and `v.list(...)`, and with OpenAPI.

### Validating and throwing

Use `validateMap` to run all checks and get the object. It throws a `ValidationException` with the errors when the input is not valid:

```dart
CreateUser user = await CreateUser.schema.validateMap(input);
```

### Validating without throwing

Use `safeValidateMap` when you want to handle the errors yourself. It never throws for bad input:

```dart
ParseResult<CreateUser> result = await CreateUser.schema.safeValidateMap(input);
if (!result.success) {
  print(result.errors); // {'email': 'The email is not a valid email'}
}
```

A `ParseResult` has:

- `success`: `true` when there are no errors.
- `value`: the result, or `null` when `success` is `false`.
- `errors`: the first message for each field, like `{'user.email': '...'}`.
- `fieldErrors`: all messages for each field.
- `issues`: the full list of `ValidationIssue` objects, with code and path.

Both methods take these options:

- `source: Source.query` reads the map like a query string, so text is converted to the field type.
- `params` are the path params. `@Unique(ignoreParam: ...)` uses them.
- `messages` and `locale` change the error text for this call. See [Messages](#messages).

`dox_core` has its own `ValidationException` (the HTTP 422 one), so it does not export the one from `dox_validation`. In a controller, both answer `422`. In tests, use `safeValidateMap`.

### Building an object with no checks

`fromMap` builds the object with **no checks**. It reads the keys, converts JSON types and fills in defaults. Use it only for data you trust, because a wrong type throws a `TypeError`:

```dart
CreateUser user = CreateUser.schema.fromMap(trustedData);
```

### Turning an object back into a map

`toMap` gives the object as a map with the input keys (snake_case). A `DateTime` becomes an ISO 8601 string and an enum becomes its name:

```dart
Map<String, dynamic> data = CreateUser.schema.toMap(user);
```

### Getting the JSON Schema

`toJsonSchema` gives the JSON Schema (draft 2020-12) of the DTO:

```dart
CreateUser.schema.toJsonSchema();
```

For a `CreateUser` with `age` and `role` fields, you get:

```json
{
  "type": "object",
  "title": "CreateUser",
  "properties": {
    "name": { "type": "string", "minLength": 3, "maxLength": 50 },
    "email": { "type": "string", "format": "email" },
    "age": { "type": ["integer", "null"], "minimum": 18 },
    "role": { "type": "string", "enum": ["admin", "user"], "default": "user" }
  },
  "required": ["name", "email"]
}
```

A `///` doc comment on a field becomes its `description`. `@Describe('...')` on a field also sets it, and wins over the comment. Each rule adds its own keys, see the [rules reference](../the-basic/validation-rules.md).

## Fluent schemas (for dynamic input)

Sometimes you only know the fields at runtime. Then use a fluent schema. The output is a `Map`, not a class:

```dart
final ObjectSchema createUser = v.object(<String, Schema<Object?>>{
  'name': v.string().trim().min(3).max(50),
  'email': v.string().email(),
  'age': v.coerce.int().min(18).optional(),
  'role': v.enumOf<String>(<String>['admin', 'user']).defaultTo('user'),
  'tags': v.list(v.string()).max(5),
  'address': Address.schema, // a DTO inside a fluent schema
});
```

Use `parse` to get the data. It throws a `ValidationException` when the input is not valid:

```dart
Map<String, dynamic> data = createUser.parse(input);
```

Use `safeParse` if you do not want it to throw:

```dart
ParseResult<Map<String, dynamic>> result = createUser.safeParse(input);
```

In a controller, use `req.validateSchema`:

```dart
Map<String, dynamic> data = await req.validateSchema(createUser);
```

Fluent schemas do not follow the DTO defaults, so watch out:

- A key is required unless you add `optional()`.
- `""` is a value, not "missing".
- Text is not converted to numbers or booleans, unless you use `v.coerce`.

### Available schemas

| Schema | Checks |
| --- | --- |
| `v.string()` | `min`, `max`, `length`, `nonEmpty`, `email`, `url`, `uuid`, `ip`, `datetime`, `regex`, `startsWith`, `endsWith`, `includes`, `alpha`, `alphaDash`, `alphaNumeric`, `json`, `digits`, `digitsBetween`, `dateFormat`, `password`, `exists`, `unique`, `trim`, `toLowerCase`, `toUpperCase` |
| `v.int()`, `v.num()` | `min`, `max`, `between`, `gt`, `lt`, `positive`, `nonNegative`, `multipleOf`, `exists`, `unique` |
| `v.bool()` | |
| `v.date()` | `DateTime` only. `min`, `max` |
| `v.enumOf([...])`, `v.literal(x)` | |
| `v.list(item)` | `min`, `max`, `nonEmpty` |
| `v.object({...})` | `strict`, `passthrough`, `strip`, `pick`, `omit`, `extend`, `partial` |
| `v.map(values, keys: ...)` | any keys |
| `v.union([...])` | the first match wins |
| `v.any()`, `v.file()` | `file()` has `maxSize`, `minSize`, `mimes`, `mimeTypes`, `dimensions`, `image` and `extensions` |

### Optional and nullable values

Every schema has these methods:

- `optional()`: the key may be missing. `null` is still an error.
- `nullable()`: the value may be `null`, but the key must be there.
- `nullish()`: both.
- `defaultTo(x)`: the value when the key is missing. (`default` is a reserved word in Dart.)

```dart
v.string().optional();
v.int().defaultTo(0);
```

Every schema also has `transform`, `refine`, `superRefine`, `use(rule)`, `same(other)`, `confirmed()`, and `describe(text)` and `example(x)` for the JSON Schema.

### Converting text

Query strings and form data are always text. `v.coerce` turns the text into the right type first:

```dart
v.coerce.int().parse('42');       // 42
v.coerce.num().parse('4.5');      // 4.5
v.coerce.bool().parse('on');      // true (true/1/yes/on, false/0/no/off)
v.coerce.date().parse('2024-01-31');
v.coerce.string().parse(5);       // '5'
```

### Checking across fields

If a rule needs two fields, use `refine` on the object. `path` says which field gets the error:

```dart
final ObjectSchema signUp = v.object(<String, Schema<Object?>>{
  'password': v.string().min(8),
  'confirm': v.string(),
}).refine((Map<String, dynamic> data) {
  return data['password'] == data['confirm'];
}, message: 'Passwords do not match', path: <Object>['confirm']);
```

### More rules

Fluent schemas have the same rules as the DTO annotations, with the same codes and messages:

```dart
final ObjectSchema signUp = v.object(<String, Schema<Object?>>{
  // needs password_confirmation with the same value
  'password': v.string().password(min: 8, mixedCase: true, numbers: true).confirmed(),
  'email': v.string().email().unique('users', column: 'email'),
  'team_id': v.int().exists('teams'),
  'type': v.enumOf<String>(<String>['person', 'company']),
  'company': v.string().optional().requiredIf('type', 'company'),
  'phone': v.string().digitsBetween(8, 12).optional(),
  'country_code': v.string().optional().requiredWith(<String>['phone']),
  'birthday': v.string().dateFormat('Y-m-d').optional(),
  'settings': v.string().json().optional(),
  'age': v.int().between(18, 120).optional(),
});

Map<String, dynamic> data = await signUp.parseAsync(input);
```

There are more presence and compare rules:

```dart
final ObjectSchema order = v.object(<String, Schema<Object?>>{
  'type': v.string(),
  'email': v.string().optional().requiredWithout(<String>['phone']),
  'phone': v.string().optional(),
  'fax': v.string().optional().requiredWithoutAll(<String>['email', 'phone']),
  'company': v.string().optional().requiredUnless('type', 'person'),
  'nick': v.string().optional().filled(),
  'note': v.string().optional().present().nullable(),
  'coupon': v.string().optional().prohibitedIf('type', 'guest'),
  'debug': v.any().optional().prohibited(),
  'terms': v.coerce.bool().accepted(),
  'new_password': v.string().different('old_password'),
  'id': v.string().ulid(),
  'min_price': v.int(),
  'max_price': v.int().gtField('min_price'),
});
```

Each rule is explained in the [rules reference](../the-basic/validation-rules.md#present-or-missing). Keep these points in mind:

- The `required...`, `prohibited...`, `filled` and `present` rules come after `optional()` (or `nullish()`).
- `exists` and `unique` ask the database, so they are async. Use `parseAsync()` or `safeParseAsync()`.
- `exists(table, column: 'id')`: the column default is `id`. Use `v.int().exists('teams')` for a number id, so text like `abc` fails before any query.
- `unique(table, column: 'email', ignore: id)`: `column` is required. `ignore` skips the row with this id, so you can use it for updates.
- `accepted()` on `v.bool()` takes only `true`. For form words like `yes` and `on`, use `v.coerce.bool().accepted()`.

### Stop at the first error

A fluent schema runs all rules of a value, and gives one error for each failed rule. If you want only the first error, add `.bail()`. A DTO always does this.

```dart
v.string().min(8).email().bail().safeParse('ab');
// one error: min_length. Without bail(): min_length and email.
```

Put `.bail()` before `.optional()`, `.nullable()` or `.transform()`, because rules after them belong to the wrapper. Async rules after a failed rule do not run, so no query is made for a value that is already wrong.

### Skip a field

Sometimes a field only matters for some input. `excludeIf(other, value)` and `excludeUnless(other, value)` skip a field of `v.object()`. When they match, the field is not checked and its key is not in the output:

```dart
final ObjectSchema account = v.object(<String, Schema<Object?>>{
  'type': v.string(),
  'vat_number': v.string().min(5).excludeIf('type', 'person'),
  'company': v.string().excludeUnless('type', 'company'),
});

account.parse(<String, dynamic>{'type': 'person', 'vat_number': 'x'});
// {type: person}
```

`other` must be a key of the same object. A skipped field never gets its default.

### Async checks

If a check needs the database, use `refineAsync`. `superRefineAsync` is the async form of `superRefine`. Then call `parseAsync()` or `safeParseAsync()`, because `parse()` throws a `StateError` when a schema has async checks:

```dart
v.string().refineAsync(isFreeName, message: 'The name is taken');
```

### Custom rules

A `Rule<T>` class works in both places: as an annotation on a DTO, and with `use()` in a fluent schema:

```dart
v.string().min(3).use(const Slug());
```

See [Custom rules](../the-basic/validation.md#custom-rules) for how to write one.

## Messages

Each error has a code, like `required` or `min_length`. A message can use placeholders: `{field}`, `{value}`, and rule values like `{min}` and `{max}`.

To change messages for the whole app, set `MessageResolver.global`. In a Dox app, use `AppConfig(validationMessages: ...)` instead:

```dart
MessageResolver.global = MessageResolver(messages: <String, String>{
  'required': 'Please fill in {field}',
});
```

To change messages for one call, pass `messages`. It replaces the global resolver for that call:

```dart
createUser.safeParse(input, messages: MessageResolver(messages: <String, String>{
  'email.required': 'We need your email',
}));
```

To show a nice name for `{field}` instead of the key, give `attributes`:

```dart
MessageResolver.global = MessageResolver(
  attributes: <String, String>{'first_name': 'first name'},
);
// The first name is required
```

A DTO can give its own names with `@Dto(attributes:)`. For other languages, extend `MessageResolver` and override `resolve()`. See [Messages](../the-basic/validation.md#messages).

## Opt-in flags

`ValidationFlags` turns on behaviors that are off by default. Set it in `Validator.flags`:

```dart
// turn on one flag
Validator.flags = const ValidationFlags(unicodeAlpha: true);

// turn on every flag
Validator.flags = const ValidationFlags.all();
```

Each isolate has its own `Validator.flags`. So in a Dox app, set it in a provider's `setup()`, which runs in every isolate:

```dart
class ValidationProvider extends DoxProvider {
  @override
  void setup() {
    Validator.flags = const ValidationFlags.all();
  }
}
```

| Flag | What it does when on |
| --- | --- |
| `emptyStringsToNull` | Fluent schemas turn each `""` into `null` before the check, also in nested maps and lists. A DTO checked on its own keeps `""`; use `@Dto(emptyStringsToNull: true)` there. |
| `unicodeAlpha` | `alpha`, `alphaNumeric` and `alphaDash` accept Unicode letters, like `José`. |
| `shortInMessage` | The default `in` message is `The selected {field} is invalid`, with no list of allowed values. |
| `dtoAllErrors` | A DTO runs the rules of every field with the right type, even when another field is missing or wrong. So one request gets all its errors at once. |
| `dtoRejectEmptyList` | A required `List` field of a DTO fails `required` on `[]`. |
| `dtoMaybeRejectsEmpty` | A `Maybe<T>` field of a DTO fails `required` when the key is sent with an empty value, like `""`. |
| `laravelMessageKeys` | A custom message key can also use the short rule name, like `name.min` for the `min_length` error. See the [list of names](../the-basic/validation.md#short-rule-names-in-message-keys). |

The three `dto...` flags need DTO code made by a current `dox_builder`, so run `dart run build_runner build` once after you turn them on.

## Without Dox

You can use `dox_validation` in any Dart program. Add the package, and the builder for DTOs:

```bash
dart pub add dox_validation
dart pub add dev:dox_builder dev:build_runner
```

```dart
import 'package:dox_validation/dox_validation.dart';
```

Run the DTO generator with `dart run build_runner build`.

### Database rules

`exists` and `unique` ask a `PresenceVerifier`. In a Dox app, `dox_orm` sets one when the database starts, so they just work. (`@Unique` and `@Exists` for DTOs are in `dox_orm`.)

Without Dox, or with another database layer, write your own. Each isolate has its own value, so set it in code that runs in every isolate:

```dart
class MyVerifier extends PresenceVerifier {
  @override
  Future<Set<String>> found(
    String table,
    String column,
    List<Object?> values, {
    String? exceptColumn,
    Object? exceptValue,
    String? connection,
  }) async {
    // Return the values that are in the column, as text.
    // Bind the values as query parameters, never put them into the SQL.
    return <String>{};
  }
}

class VerifierProvider extends DoxProvider {
  @override
  void setup() {
    PresenceVerifier.instance = MyVerifier();
  }
}
```

## Details

- Every schema and every `DtoSchema` implements the [Standard Schema](https://standardschema.dev) interface (`StandardSchema`). Code that only needs to validate can take any `StandardSchema`.
- `parse`, `safeParse`, `parseAsync` and `safeParseAsync` also work on a `DtoSchema`, with `Source.body`. `parse` throws a `StateError` when the DTO has async rules.
- In the JSON Schema, a nested DTO goes in `$defs` with a `$ref`, and `@Dto(strict: true)` adds `"additionalProperties": false`.
- An app with no DTO gets an empty `final` list in `dtos.g.dart`.
- Table and column names for `exists` and `unique` may use letters, digits, `_` and `$`, with `.` between parts. Other names throw an `ArgumentError` when the schema is built.
- `unique` never takes the column from the input key, because a key in `v.map()` comes from the user.
- The database decides if two values match. On MySQL, `TAKEN@dox.dev` is taken when `taken@dox.dev` is there.
- `prohibited()` fails on any sent value except blank text, also on `null`, `[]`, `0` and `false`. `prohibitedIf()` lets `null`, blank text and empty lists or maps pass.
- `accepted()` on `v.string()` or `v.any()` takes the exact words `true`, `1`, `"1"`, `"true"`, `"yes"` and `"on"` (case sensitive). `declined()` takes `false`, `0`, `"0"`, `"false"`, `"no"` and `"off"`.
- `gtField`, `gteField`, `ltField` and `lteField` fail when the other key is missing.
- `.bail()` counts for all rules of that schema, wherever it is in the chain. On `v.object()` or `v.list()`, each field and item keeps its own setting.
- `excludeIf` does not skip when the other key is missing. `excludeUnless` treats a missing key as `null`, so it skips. Both work only on a field of `v.object()`, not on a top-level value, list item or `v.map()` value. Other rules that read the skipped key still see its raw input.
- A per-call `MessageResolver` falls back to the built-in text, not the global text.

## See also

- [Validation](../the-basic/validation.md): check a request in a Dox app.
- [Validation rules](../the-basic/validation-rules.md): every rule.
- [Share code with Flutter](../guides/share-code-with-flutter.md): use the same DTOs in a Flutter app.

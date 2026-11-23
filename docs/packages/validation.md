---
icon: lucide/list-checks
---

# Validation

`dox_validation` checks input and gives you typed Dart objects.

It has two parts. A **DTO** is a class with `@Dto()` and rule annotations, and a generator writes its checks. Use it for almost all input, see [DTOs](../the-basic/dto.md). A **fluent schema** like `v.object(...)` is for input whose shape you know only at runtime. Both give all errors at once, and both give a JSON Schema for [OpenAPI](openapi.md).

## Setup

`dox_core` exports `dox_validation`, so you install nothing. Import `package:dox_core/dox_core.dart`.

1. Make a DTO with `dox make:dto CreateUser`. It writes `lib/app/dtos/create_user/create_user.dto.dart`.
2. Run the generator: `dox build_runner:build`.
3. Give the list of DTOs to the app:

    ```dart title="lib/config/app.dart"
    import 'package:my_app/generated/dtos.g.dart';

    AppConfig appConfig = AppConfig(
      // ...
      dtos: dtos, // from lib/generated/dtos.g.dart
    );
    ```

Then ask for the DTO in a controller. Dox checks the body before the method runs, and bad input gets 422 with the errors:

```dart title="lib/app/http/controllers/user.controller.dart"
class UserController {
  Future<Map<String, dynamic>> store(CreateUser body) async {
    // body is already checked and typed
    return <String, dynamic>{'name': body.name};
  }
}
```

The full guide is [Validation](../the-basic/validation.md), and every rule is in the [rules reference](../the-basic/validation-rules.md). This page is about the package.

## Defining a DTO

Give each field its rules as annotations:

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

The generator writes a `DtoSchema<CreateUser>` named `$CreateUserDto`, with the checks, the converter and the JSON Schema. The `schema` line lets you use it as `CreateUser.schema`. The generator also writes `lib/generated/dtos.g.dart`, with the list `dtos` of every DTO in `lib/`.

## Validating a map

A `DtoSchema` is also a normal `Schema`. You can use it inside `v.object(...)` and `v.list(...)`, and with OpenAPI.

### Validating and throwing

`validateMap` runs all checks and gives the object. Bad input throws a `ValidationException` with the errors:

```dart
CreateUser user = await CreateUser.schema.validateMap(input);
```

In a controller, this answers 422. `dox_core` has its own `ValidationException` and does not export the one of `dox_validation`.

### Validating without throwing

`safeValidateMap` gives a `ParseResult`, and never throws for bad input:

```dart
ParseResult<CreateUser> result =
    await CreateUser.schema.safeValidateMap(input);
if (!result.success) {
  print(result.errors); // {'email': 'The email is not a valid email'}
}
```

A `ParseResult` has:

- `success`: true when there are no errors.
- `value`: the result, or null when `success` is false.
- `errors`: the first message for each field, like `{'user.email': '...'}`.
- `fieldErrors`: all messages for each field.
- `issues`: the full list of `ValidationIssue` objects, with code and path.

Both methods take these options:

- `source: Source.query` reads the map like a query string, so text is converted to the field type.
- `params` are the path params, for `@Unique(ignoreParam: ...)`.
- `messages` and `locale` change the error text for this call. See [Messages](#messages).

`parse`, `safeParse`, `parseAsync` and `safeParseAsync` also work on a `DtoSchema`. `parse` throws a `StateError` when the DTO has async rules.

### Building an object with no checks

`fromMap` builds the object with no checks. It reads the keys, converts JSON types and fills in defaults. Use it only for data you trust, because a wrong type throws a `TypeError`:

```dart
CreateUser user = CreateUser.schema.fromMap(trustedData);
```

### Turning an object back into a map

`toMap` gives the object as a map with the input keys. A `DateTime` becomes an ISO 8601 string, and an enum becomes its name:

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

A `///` doc comment on a field becomes its `description`. `@Describe('...')` also sets it, and wins over the comment. A nested DTO goes in `$defs` with a `$ref`, and `@Dto(strict: true)` adds `"additionalProperties": false`.

## Fluent schemas (for dynamic input)

When you know the fields only at runtime, use a fluent schema. The output is a map, not a class:

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

`parse` gives the data, and throws a `ValidationException` for bad input. `safeParse` gives a `ParseResult`:

```dart
Map<String, dynamic> data = createUser.parse(input);

ParseResult<Map<String, dynamic>> result = createUser.safeParse(input);
```

In a controller, use `req.validateSchema`:

```dart
Map<String, dynamic> data = await req.validateSchema(createUser);
```

Fluent schemas do not use the DTO defaults:

- A key is required, unless you add `optional()`.
- An empty string is a value, not "missing".
- Text is not converted to numbers or booleans, unless you use `v.coerce`.

### Available schemas

| Schema | Checks |
| --- | --- |
| `v.string()` | `min`, `max`, `length`, `nonEmpty`, `email`, `url`, `uuid`, `ulid`, `ip`, `datetime`, `regex`, `startsWith`, `endsWith`, `includes`, `alpha`, `alphaDash`, `alphaNumeric`, `json`, `digits`, `digitsBetween`, `dateFormat`, `hexColor`, `password`, `exists`, `unique`, `trim`, `toLowerCase`, `toUpperCase` |
| `v.int()`, `v.num()` | `min`, `max`, `between`, `gt`, `lt`, `positive`, `nonNegative`, `multipleOf`, `gtField`, `gteField`, `ltField`, `lteField`, `exists`, `unique` |
| `v.bool()` | |
| `v.date()` | `DateTime` only. `min`, `max` |
| `v.enumOf([...])`, `v.literal(x)` | |
| `v.list(item)` | `min`, `max`, `nonEmpty` |
| `v.object({...})` | `strict`, `passthrough`, `strip`, `pick`, `omit`, `extend`, `partial` |
| `v.map(values, keys: ...)` | any keys |
| `v.union([...])` | the first match wins |
| `v.any()`, `v.file()` | `file()` has `maxSize`, `minSize`, `mimes`, `mimeTypes`, `dimensions`, `image` and `extensions` |

`gtField`, `gteField`, `ltField` and `lteField` fail when the other key is missing.

### Optional and nullable values

Every schema has these methods:

- `optional()`: the key can be missing. Null is still an error.
- `nullable()`: the value can be null, but the key must be there.
- `nullish()`: both.
- `defaultTo(x)`: the value when the key is missing.

```dart
v.string().optional();
v.int().defaultTo(0);
```

Every schema also has `transform`, `refine`, `superRefine`, `use(rule)`, `same(other)`, `different(other)`, `confirmed()`, `accepted()`, `declined()`, and `describe(text)` and `example(x)` for the JSON Schema.

### Converting text

Query strings and form data are always text. `v.coerce` turns the text into the type first:

```dart
v.coerce.int().parse('42');       // 42
v.coerce.num().parse('4.5');      // 4.5
v.coerce.bool().parse('on');      // true (true/1/yes/on, false/0/no/off)
v.coerce.date().parse('2024-01-31');
v.coerce.string().parse(5);       // '5'
```

### Checking across fields

For a rule on two fields, use `refine` on the object. `path` sets the field that gets the error:

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
  'password': v.string()
      .password(min: 8, mixedCase: true, numbers: true)
      .confirmed(),
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
  'fax': v.string().optional()
      .requiredWithoutAll(<String>['email', 'phone']),
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

Each rule is in the [rules reference](../the-basic/validation-rules.md#present-or-missing). Keep these points in mind:

- The `required...`, `prohibited...`, `filled` and `present` rules come after `optional()` (or `nullish()`).
- `exists` and `unique` ask the database, so they are async. Use `parseAsync()` or `safeParseAsync()`.
- `exists(table, column: 'id')`: the column default is `id`. Use `v.int().exists('teams')` for a number id, so text like `abc` fails before a query.
- `unique(table, column: 'email', ignore: id)`: `column` is required. `ignore` skips the row with this id, for updates.
- A table or column name can have letters, digits, `_` and `$`, with `.` between parts. Other names throw an `ArgumentError`.
- The database decides if two values match. On MySQL, `TAKEN@dox.dev` is taken when `taken@dox.dev` is there.
- `accepted()` on `v.bool()` takes only true. For form words like `yes` and `on`, use `v.coerce.bool().accepted()`.

### Stop at the first error

A fluent schema gives one error for each failed rule of a value. Add `.bail()` to get only the first error. A DTO always does this:

```dart
v.string().min(8).email().bail().safeParse('ab');
// one error: min_length. Without bail(): min_length and email.
```

Put `.bail()` before `.optional()`, `.nullable()` or `.transform()`, because rules after them belong to the wrapper. Async rules after a failed rule do not run.

### Skip a field

`excludeIf(other, value)` and `excludeUnless(other, value)` skip a field of `v.object()`. When they match, the field is not checked and its key is not in the output:

```dart
final ObjectSchema account = v.object(<String, Schema<Object?>>{
  'type': v.string(),
  'vat_number': v.string().min(5).excludeIf('type', 'person'),
  'company': v.string().excludeUnless('type', 'company'),
});

account.parse(<String, dynamic>{'type': 'person', 'vat_number': 'x'});
// {type: person}
```

`other` must be a key of the same object. A skipped field never gets its default. When `other` is missing, `excludeIf` does not skip, and `excludeUnless` skips.

### Async checks

For a check that needs the database, use `refineAsync`, or `superRefineAsync` in place of `superRefine`. Then call `parseAsync()` or `safeParseAsync()`, because `parse()` throws a `StateError`:

```dart
v.string().refineAsync(isFreeName, message: 'The name is taken');
```

### Custom rules

A `Rule<T>` class works as an annotation on a DTO, and with `use()` in a fluent schema:

```dart
v.string().min(3).use(const Slug());
```

See [Custom rules](../the-basic/validation.md#custom-rules) to write one.

### Standard Schema

Every schema and every `DtoSchema` implements the [Standard Schema](https://standardschema.dev) interface. Code that only validates can take any `StandardSchema` and call `validate`:

```dart
StandardResult<Object?> result = await schema.validate(input);
```

## Messages

Each error has a code, like `required` or `min_length`. A message can use placeholders: `{field}`, `{value}`, and rule values like `{min}` and `{max}`.

To change messages for the whole app, set `MessageResolver.global`. In a Dox app, use `AppConfig(validationMessages: ...)`:

```dart
MessageResolver.global = MessageResolver(messages: <String, String>{
  'required': 'Please fill in {field}',
});
```

To add messages to a resolver later, use `setMessages`:

```dart
MessageResolver.global.setMessages(<String, String>{
  'email.required': 'We need your email',
});
```

To change messages for one call, give `messages`. It replaces the global resolver for that call, and falls back to the built-in text:

```dart
createUser.safeParse(input,
    messages: MessageResolver(messages: <String, String>{
      'email.required': 'We need your email',
    }));
```

To show a name for `{field}` in place of the key, give `attributes`, or call `setAttributes`:

```dart
MessageResolver.global = MessageResolver(
  attributes: <String, String>{'first_name': 'first name'},
);
// The first name is required
```

A DTO can give its own names with `@Dto(attributes:)`. For other languages, extend `MessageResolver` and override `resolve()`. See [Messages](../the-basic/validation.md#messages).

## Opt-in flags

`ValidationFlags` turns on behavior that is off by default. Set it in `Validator.flags`:

```dart
// turn on one flag
Validator.flags = const ValidationFlags(unicodeAlpha: true);

// turn on every flag
Validator.flags = const ValidationFlags.all();
```

Each isolate has its own `Validator.flags`. In a Dox app, set it in the `setup()` of a provider, which runs in every isolate:

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
| `emptyStringsToNull` | Fluent schemas change each empty string to null before the check, also in nested maps and lists. For a DTO, use `@Dto(emptyStringsToNull: true)`. |
| `unicodeAlpha` | `alpha`, `alphaNumeric` and `alphaDash` accept Unicode letters, like `José`. |
| `shortInMessage` | The default `in` message is `The selected {field} is invalid`, with no list of allowed values. |
| `dtoAllErrors` | A DTO runs the rules of every field with the right type, also when another field is missing or wrong. |
| `dtoRejectEmptyList` | A required `List` field of a DTO fails `required` on `[]`. |
| `dtoMaybeRejectsEmpty` | A `Maybe<T>` field of a DTO fails `required` when the key has an empty value, like `""`. |
| `laravelMessageKeys` | A custom message key can also use the short rule name, like `name.min` for the `min_length` error. See the [list of names](../the-basic/validation.md#short-rule-names-in-message-keys). |

After you turn on a `dto...` flag, run `dart run build_runner build` one time.

## Without Dox

`dox_validation` works in any Dart program. Add the package, and the builder for DTOs:

```bash
dart pub add dox_validation
dart pub add dev:dox_builder dev:build_runner
```

```dart
import 'package:dox_validation/dox_validation.dart';
```

Run the DTO generator with `dart run build_runner build`.

### Database rules

`exists` and `unique` ask a `PresenceVerifier`. In a Dox app, `dox_orm` sets one when the database starts. `@Unique` and `@Exists` for DTOs are in `dox_orm`.

With another database layer, write your own. Each isolate has its own value, so set it in code that runs in every isolate:

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

## Next steps

- [Validation](../the-basic/validation.md): check a request in a Dox app.
- [Validation rules](../the-basic/validation-rules.md): every rule.
- [Share code with Flutter](../guides/share-code-with-flutter.md): use the same DTOs in a Flutter app.

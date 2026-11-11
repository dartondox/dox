---
icon: lucide/list-checks
---

# Validation

`dox_validation` checks input and gives you typed Dart objects.

It has two parts:

1. **DTOs**: a class with `@Dto()` and rule annotations. A generator writes the checks. Use this for almost everything.
2. **Fluent schemas**: `v.object(...)`, like [Zod](https://zod.dev). Use it only when the shape is known at runtime.

Both give all errors at once, and a JSON Schema for [OpenAPI](openapi.md).

## In a Dox app

`dox_core` uses `dox_validation` and exports it. There is nothing to install: `import 'package:dox_core/dox_core.dart'` is all you need.

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

The full guide is at [Validation](../the-basic/validation.md). Every rule is in the [rules reference](../the-basic/validation-rules.md).
The rest of this page is about the package itself.

## Without Dox

```bash
dart pub add dox_validation
dart pub add dev:dox_builder dev:build_runner
```

```dart
import 'package:dox_validation/dox_validation.dart';
```

The DTO generator is in `dox_builder`. Run it with `dart run build_runner build`.
`@Unique` and `@Exists` are in `dox_orm`, not here.

## DTOs

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

The generator makes, for each `@Dto` class:

| Name | What it is |
| --- | --- |
| `$CreateUserDto` | a `const` `DtoSchema<CreateUser>`: the checks, the converter and the JSON Schema |
| `lib/generated/dtos.g.dart` | `const List<DtoSchema<Object>> dtos`: every DTO in `lib/`. Dox uses it to find DTOs by type. An app with no DTO gets an empty `final` list. |

The `static const ... schema = $CreateUserDto;` line is how you reach the schema: `CreateUser.schema`.

## `DtoSchema<T>`

`DtoSchema<T>` is also a `Schema<T>`. So it works everywhere a schema works:
inside `v.object(...)`, `v.list(...)`, with OpenAPI, and as a `StandardSchema`.

| Member | Does |
| --- | --- |
| `Future<T> validateMap(Map<String, dynamic> input, {Source source = Source.body, Map<String, String> params = const {}, MessageResolver? messages, String? locale})` | all checks, then the object. Throws `ValidationException` with the errors. |
| `Future<ParseResult<T>> safeValidateMap(input, {source, params, messages, locale})` | the same, but never throws for bad input. `result.success`, `result.value`, `result.errors`. |
| `T fromMap(Map<String, dynamic> input)` | builds the object with **no checks**. Reads keys, converts JSON types, uses defaults. A wrong type throws a `TypeError`. Only for data you trust. |
| `Map<String, dynamic> toMap(T value)` | the object as a map with the input keys (snake_case). `DateTime` becomes an ISO 8601 string, an enum its name. |
| `Map<String, dynamic> toJsonSchema()` | JSON Schema (draft 2020-12). |
| `parse`, `safeParse`, `parseAsync`, `safeParseAsync` | the normal `Schema` methods, with `Source.body`. `parse` throws a `StateError` when the DTO has async rules. |
| `Type get type`, `String get name` | `CreateUser` and `'CreateUser'`. |

`source: Source.query` reads the map like a query string: text is converted to the field type.
`params` are path params, used by `@Unique(ignoreParam: ...)`.
`messages` and `locale` change the error text for this call. See [Messages](#messages).

```dart
ParseResult<CreateUser> result = await CreateUser.schema.safeValidateMap(input);
if (!result.success) {
  print(result.errors); // {'email': 'The email is not a valid email'}
}
```

| `ParseResult` member | What it is |
| --- | --- |
| `success` | `true` when there are no errors |
| `value` | the result. `null` when `success` is `false` |
| `errors` | the first message for each field, like `{'user.email': '...'}` |
| `fieldErrors` | all messages for each field |
| `issues` | the full list of `ValidationIssue` objects, with code and path |

!!! note
    `dox_core` has its own `ValidationException` (the HTTP 422 one), so it does not export the one from `dox_validation`.
    In a Dox app, both answer `422` when thrown in a controller. In tests, prefer `safeValidateMap`.

### JSON Schema of a DTO

For the `CreateUser` from the [Validation guide](../the-basic/validation.md) (with `age` and `role`):

```dart
CreateUser.schema.toJsonSchema();
```

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

- `required` lists the required fields only.
- A nullable field has `"type": [..., "null"]`. A default becomes `default`.
- A nested DTO goes in `$defs` under its class name, with a `$ref`. OpenAPI moves it to `components/schemas`.
- `@Dto(strict: true)` adds `"additionalProperties": false`.
- A `///` doc comment on a field becomes `description`. `@Describe('...')` on a field sets it too, and wins over the comment. It does not change the checks.
- Each rule adds its keys. See the [rules reference](../the-basic/validation-rules.md).

## Fluent schemas (for dynamic input)

Use these when you only know the fields at runtime. The output is a `Map`, not a class.

```dart
final ObjectSchema createUser = v.object(<String, Schema<Object?>>{
  'name': v.string().trim().min(3).max(50),
  'email': v.string().email(),
  'age': v.coerce.int().min(18).optional(),
  'role': v.enumOf<String>(<String>['admin', 'user']).defaultTo('user'),
  'tags': v.list(v.string()).max(5),
  'address': Address.schema, // a DTO inside a fluent schema
});

// throws ValidationException when the input is not valid
Map<String, dynamic> data = createUser.parse(input);

// never throws for bad input
ParseResult<Map<String, dynamic>> result = createUser.safeParse(input);
```

In a controller: `Map<String, dynamic> data = await req.validateSchema(createUser);`

!!! warning "Different defaults"
    Fluent schemas do not follow the DTO rules. A key is required unless you add `optional()`.
    `""` is a value, not "missing". Text is not converted, unless you use `v.coerce`.

### Schemas

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

On every schema:

- `optional()`: the key may be missing. `null` is still an error.
  After it: `requiredIf(other, value)` and `requiredWith([others])`.
- `nullable()`: the value may be `null`. The key must be there.
- `nullish()`: both.
- `defaultTo(x)`: the value when the key is missing. (`default` is a reserved word in Dart.)
- `transform(fn)`, `refine(fn)`, `refineAsync(fn)`, `superRefine(fn)`, `superRefineAsync(fn)`, `use(rule)`.
- `same(other)`, `confirmed()`: compare with another key of the same object.
- `bail()`: stop at the first failed rule. See [Stop at the first error](#stop-at-the-first-error).
- `excludeIf(other, value)`, `excludeUnless(other, value)`: leave a key out. See [Skip a field](#skip-a-field).
- `describe(text)`, `example(x)`: only used in the JSON Schema.

### Coercion

Query strings and form data are text. `v.coerce` turns text into the right type first.

```dart
v.coerce.int().parse('42');       // 42
v.coerce.num().parse('4.5');      // 4.5
v.coerce.bool().parse('on');      // true (true/1/yes/on, false/0/no/off)
v.coerce.date().parse('2024-01-31');
v.coerce.string().parse(5);       // '5'
```

### Checks across fields

```dart
final ObjectSchema signUp = v.object(<String, Schema<Object?>>{
  'password': v.string().min(8),
  'confirm': v.string(),
}).refine((Map<String, dynamic> data) {
  return data['password'] == data['confirm'];
}, message: 'Passwords do not match', path: <Object>['confirm']);
```

### More rules

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

They use the same codes and messages as the DTO annotations. See the [rules reference](../the-basic/validation-rules.md#more-text-rules).

- `requiredIf` and `requiredWith` come after `optional()` or `nullish()`.
  Then a missing, `null` or blank value is an error when the condition is true.

More Laravel rules:

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

- `requiredUnless`, `requiredWithout`, `requiredWithoutAll`, `filled` and `present` come after `optional()`, like `requiredIf`.
- `present()` needs the key. Add `.nullable()` to allow `null`.
- `prohibited()` and `prohibitedIf()` come after `optional()`. Like Laravel, they treat empty values in different ways:
    - `prohibited()`: a missing key or blank text passes. Any other sent value fails, also `null`, `[]`, `0` and `false`.
    - `prohibitedIf()`: when the condition matches, a missing key, `null`, blank text and an empty list or map pass. `0`, `false` and any other value fail.
- `accepted()` and `declined()` check the value after the type check. `v.bool()` takes only `true` and `false`, so `"yes"` is a `boolean` error there. Use `v.coerce.bool().accepted()` for form words like `yes` and `on` (any case), or `v.string()` or `v.any()` to check the exact Laravel words.
- `gtField`, `gteField`, `ltField` and `lteField` compare with another key, like Laravel `gt:field`. A missing other key fails.
- The rules are explained in the [rules reference](../the-basic/validation-rules.md#present-or-missing).
- `exists` and `unique` are async. Use `parseAsync()` or `safeParseAsync()`.
- For one value, the database decides what matches. On MySQL `TAKEN@dox.dev` is taken when `taken@dox.dev` is there.
- `exists(table, column: 'id')`: the column default is `id`. For a number id column, use `v.int().exists('teams')`, not `v.string()`. Then text like `abc` is a type error, before any query.
- `unique(table, column: 'email', ignore: id)`: `column` is required. It is never taken from the input key, because a key in `v.map()` comes from the user. `ignore` skips the row where `ignoreColumn` (default `id`) has this value. Use it for updates.

#### Stop at the first error

A fluent schema runs all rules of a value, and gives one error for each failed rule. Add `.bail()` to stop at the first failed rule, like Laravel `bail`. A DTO always does this.

```dart
v.string().min(8).email().bail().safeParse('ab');
// one error: min_length. Without bail(): min_length and email.
```

- It counts for all rules of that schema, wherever you put `.bail()` in the chain.
- Async rules after a failed rule do not run. So no database query is made for a value that is already wrong.
- Put it before `.optional()`, `.nullable()` or `.transform()`. A rule after one of them belongs to the wrapper, so it does not count. `.bail()` after a wrapper, like `.optional().bail()`, does nothing for the rules inside it.
- On `v.object()` or `v.list()`, it counts for the rules of the object or list only. Each field and each item keeps its own setting.
- A type error already stops the rules of a value, with or without `.bail()`.

#### Skip a field

`excludeIf(other, value)` and `excludeUnless(other, value)` skip a field of `v.object()`, like Laravel `exclude_if` and `exclude_unless`. When they match, the field is not checked, and its key is not in the output.

```dart
final ObjectSchema account = v.object(<String, Schema<Object?>>{
  'type': v.string(),
  'vat_number': v.string().min(5).excludeIf('type', 'person'),
  'company': v.string().excludeUnless('type', 'company'),
});

account.parse(<String, dynamic>{'type': 'person', 'vat_number': 'x'});
// {type: person}
```

- They work like the DTO `@ExcludeIf` and `@ExcludeUnless`. They read the raw input of the other key, and match like `requiredIf` (also with a list of values).
- `other` is a key of the same object. A dotted path like `user.type` does not work.
- `excludeIf`: a missing other key does not skip. `excludeUnless`: a missing other key counts as `null`, so the field is skipped.
- The key is left out also with `.optional()`, `.nullable()` or `.defaultTo()`, in any order. A skipped field never gets its default.
- In a `v.list()` of objects, each item is checked on its own.
- A skipped key is not an unknown key for `strict()`, and `passthrough()` does not add it back.
- In the JSON Schema, the field is not in `required`.
- The rules of other fields that read this key (like `same`, `requiredIf` or `gtField`) still see its raw input, also when it is skipped.
- They work only on a field of `v.object()`. On a top-level value, a list item or a value of `v.map()`, they do nothing.

#### The presence verifier

`exists` and `unique` ask a `PresenceVerifier` (like in Laravel). `dox_orm` sets one when the database starts, so in a Dox app they just work.
Outside Dox, or with another database layer, set your own. Each isolate has its own value, so set it in a provider's `setup()`, which runs in every isolate:

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

Table and column names are checked when the schema is built. They take the same names as the dox_orm query builder: letters, digits, `_` and `$`, with `.` between parts, like `2fa_codes` or `public.users`. Other names throw an `ArgumentError`.

### Async checks

`refineAsync` runs a check that needs the database. Then use `parseAsync()` or `safeParseAsync()`.
`parse()` throws a `StateError` when a schema has async checks.

### Custom rules in a fluent schema

A `Rule<T>` class works in both worlds: as an annotation on a DTO, and with `use()` here.

```dart
v.string().min(3).use(const Slug());
```

See [Custom rules](../the-basic/validation.md#custom-rules) for how to write one.

## Messages

Each error has a code, like `required` or `min_length`.
Placeholders: `{field}`, `{value}`, and rule values like `{min}` and `{max}`.

```dart
// for the whole app (outside Dox; in Dox use AppConfig(validationMessages: ...))
MessageResolver.global = MessageResolver(messages: <String, String>{
  'required': 'Please fill in {field}',
});

// for one call
createUser.safeParse(input, messages: MessageResolver(messages: <String, String>{
  'email.required': 'We need your email',
}));
```

A resolver for one call is used in place of the global one.
Codes that it does not have get the built-in text, not the global text.

With the flag `laravelMessageKeys`, a key can use the Laravel rule name too, like `name.min` for the `min_length` error. See the [list of names](../the-basic/validation.md#laravel-rule-names-in-message-keys).

To show a name for `{field}` in place of the key, give `attributes`:

```dart
MessageResolver.global = MessageResolver(
  attributes: <String, String>{'first_name': 'first name'},
);
// The first name is required
```

A DTO can give its own names with `@Dto(attributes:)`. See [Names for `{field}`](../the-basic/validation.md#names-for-field).

For other languages, extend `MessageResolver` and override `resolve()`.
See [Messages](../the-basic/validation.md#messages).

## Opt-in flags

`ValidationFlags` turns on behaviors that are off by default.
Set it in `Validator.flags`.

```dart
// turn on one flag
Validator.flags = const ValidationFlags(unicodeAlpha: true);

// turn on every flag
Validator.flags = const ValidationFlags.all();
```

| Flag | What it does when on |
| --- | --- |
| `emptyStringsToNull` | Fluent schemas turn each `""` in the input into `null` before they check it. This also happens in nested maps and lists. So `""` fails a required field, and `.nullable()` gives `null`. |
| `unicodeAlpha` | `alpha`, `alphaNumeric` and `alphaDash` accept Unicode letters and marks, like `José`. `alphaNumeric` and `alphaDash` also accept Unicode digits. This works for fluent schemas and DTOs. |
| `shortInMessage` | The default `in` message is `The selected {field} is invalid`. It does not list the allowed values. |
| `dtoAllErrors` | A DTO runs the rules of each field that has the right type, also when another field is missing or has the wrong type. So one request gets all its errors at once. The type and `required` errors come first (a nested DTO's errors at its field), then the rule errors. A list or map with a bad item skips its rules. |
| `dtoRejectEmptyList` | A required `List` field of a DTO fails `required` on `[]`, and its other rules do not run. It does not apply to a nullable list, a list with a default, or a `Maybe<List>`. |
| `dtoMaybeRejectsEmpty` | A `Maybe<T>` field of a DTO (with `T` not nullable) fails `required` when the key is sent with an empty value, like `""`. A missing key still gives `Maybe.missing()`. It does not apply to `Maybe<T?>`. A text of only spaces is a value and passes. With `@Trim` it becomes `""` and fails. |
| `laravelMessageKeys` | A custom message key can use the Laravel rule name of a code, like `name.min` for the `min_length` error. It works in `@Dto(messages:)` and in a `MessageResolver`. At each step of the lookup the Dox code wins. The error code does not change. See the [list of names](../the-basic/validation.md#laravel-rule-names-in-message-keys). |

With a flag off, the check works as described in the rest of this page:
`""` is text, the alpha rules take only `a-z`, `A-Z` and `0-9`, the `in` message lists the allowed values, and a message key matches only the Dox code.
For DTOs: a missing field or a type error stops the rules of the other fields, `[]` passes a required list, and `""` in a `Maybe` field counts as not sent.

The three DTO flags are read when the check runs.
They need the DTO code from a `dox_builder` that knows them.
Run `dart run build_runner build` once to make it.

`emptyStringsToNull` is for fluent schemas.
A DTO checked on its own keeps `""`; use `@Dto(emptyStringsToNull: true)` there.
A DTO inside a fluent schema gets the changed input.

Each isolate has its own `Validator.flags`.
In a Dox app, set it in a provider's `setup()`, so every isolate runs it:

```dart
class ValidationProvider extends DoxProvider {
  @override
  void setup() {
    Validator.flags = const ValidationFlags.all();
  }
}
```

## Standard Schema

Every schema, and every `DtoSchema`, implements the [Standard Schema](https://standardschema.dev) interface (`StandardSchema`).
Code that only needs to validate can accept any `StandardSchema`, from Dox or from another library.

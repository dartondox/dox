---
icon: lucide/list-checks
---

# Validation

`dox_validation` checks input and gives you typed Dart objects.
It has two parts:

1. **DTOs**: a class with `@Dto()` and rule annotations. A generator writes the checks. Use this for almost everything.
2. **Fluent schemas**: `v.object(...)`, like [Zod](https://zod.dev). Use it only when the shape is known at runtime.

Both give all errors at once, and a JSON Schema for [OpenAPI](openapi.md).

!!! tip "Built into Dox"
    `dox_core` uses `dox_validation` and exports it. `import 'package:dox_core/dox_core.dart'` is all you need.
    The guide is at [Validation](../the-basic/validation.md). Every rule is in the [rules reference](../the-basic/validation-rules.md).
    This page is about the package itself, and about using it outside Dox.

## Install (outside Dox)

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
| `lib/generated/dtos.g.dart` | `const List<DtoSchema<Object>> dtos`: every DTO in `lib/`. Dox uses it to find DTOs by type. |

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
- A `///` doc comment on a field becomes `description`.
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
| `v.string()` | `min`, `max`, `length`, `nonEmpty`, `email`, `url`, `uuid`, `ip`, `datetime`, `regex`, `startsWith`, `endsWith`, `includes`, `alpha`, `alphaDash`, `alphaNumeric`, `trim`, `toLowerCase`, `toUpperCase` |
| `v.int()`, `v.num()` | `min`, `max`, `gt`, `lt`, `positive`, `nonNegative`, `multipleOf` |
| `v.bool()` | |
| `v.date()` | `DateTime` only. `min`, `max` |
| `v.enumOf([...])`, `v.literal(x)` | |
| `v.list(item)` | `min`, `max`, `nonEmpty` |
| `v.object({...})` | `strict`, `passthrough`, `strip`, `pick`, `omit`, `extend`, `partial` |
| `v.map(values, keys: ...)` | any keys |
| `v.union([...])` | the first match wins |
| `v.any()`, `v.file()` | `file()` has `image` and `extensions` |

On every schema:

- `optional()`: the key may be missing. `null` is still an error.
- `nullable()`: the value may be `null`. The key must be there.
- `nullish()`: both.
- `defaultTo(x)`: the value when the key is missing. (`default` is a reserved word in Dart.)
- `transform(fn)`, `refine(fn)`, `refineAsync(fn)`, `superRefine(fn)`, `superRefineAsync(fn)`, `use(rule)`.
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

For other languages, extend `MessageResolver` and override `resolve()`.
See [Messages](../the-basic/validation.md#messages).

## Standard Schema

Every schema, and every `DtoSchema`, implements the [Standard Schema](https://standardschema.dev) interface (`StandardSchema`).
Code that only needs to validate can accept any `StandardSchema`, from Dox or from another library.

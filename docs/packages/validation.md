# Validation schemas

`dox_validation` checks data with typed schemas, like [Zod](https://zod.dev).
You describe the shape once. You get typed output, all errors at once, and a JSON Schema for free.

!!! tip "Built into Dox"
    `dox_core` uses `dox_validation` for `req.validate()`, and it exports it.
    In a Dox app you do not add or import anything: `import 'package:dox_core/dox_core.dart'` gives `v`, `Schema` and the rest.
    See [Validation](../the-basic/validation.md) for `req.validate()`, `validateAsync()`, `validateSchema()` and the `unique` / `exists` rules.

## Install (outside Dox)

```bash
dart pub add dox_validation
```

```dart
import 'package:dox_validation/dox_validation.dart';
```

## Quick start

```dart
final ObjectSchema createUser = v.object(<String, Schema<Object?>>{
  'name': v.string().trim().min(3).max(50),
  'email': v.string().email(),
  'age': v.coerce.int().min(18).optional(),
  'role': v.enumOf<String>(<String>['admin', 'user']).defaultTo('user'),
  'tags': v.list(v.string()).max(5),
});

// throws ValidationException when the input is not valid
Map<String, dynamic> data = createUser.parse(input);

// never throws for bad input
ParseResult<Map<String, dynamic>> result = createUser.safeParse(input);
if (!result.success) {
  print(result.errors); // {'email': 'The email is not a valid email'}
}
```

## Use it in a controller

```dart
class UserController {
  Future<dynamic> store(DoxRequest req) async {
    // 422 with {field: message} when it fails
    Map<String, dynamic> data = await req.validateSchema(createUser);
    // ... save data
  }
}
```

Or in a [form request](../the-basic/request.md#schema): return the schema from `schema()`.
A `schema.parse()` that throws inside a controller also answers `422`.

!!! note
    `dox_core` exports `dox_validation` without its `ValidationException`, because `dox_core` has its own
    (the HTTP 422 one). `dox_orm` also has a `Schema` class. In a file that uses both, import `dox_orm` with a prefix.

## Schemas

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
- `transform(fn)`, `refine(fn)`, `refineAsync(fn)`, `superRefine(fn)`, `use(rule)`.
- `describe(text)`, `example(x)`: only used in the JSON Schema.

## Coercion

Query strings and form data are always text. `v.coerce` turns text into the right type first.

```dart
v.coerce.int().parse('42');       // 42
v.coerce.num().parse('4.5');      // 4.5
v.coerce.bool().parse('on');      // true (true/1/yes/on, false/0/no/off)
v.coerce.date().parse('2024-01-31');
v.coerce.string().parse(5);       // '5'
```

## Checks across fields

```dart
final ObjectSchema signUp = v.object(<String, Schema<Object?>>{
  'password': v.string().min(8),
  'confirm': v.string(),
}).refine((Map<String, dynamic> data) {
  return data['password'] == data['confirm'];
}, message: 'Passwords do not match', path: <Object>['confirm']);
```

## Async checks

Use `refineAsync` for a check that needs the database.

```dart
final StringSchema email = v.string().email().refineAsync(
  (String value) async {
    return !(await users.emailExists(value));
  },
  message: 'The {field} is already taken',
);

await email.parseAsync('a@dox.dev');
```

!!! warning
    `parse()` throws a `StateError` when a schema has async checks.
    Use `parseAsync()` or `safeParseAsync()` then.

## Custom rules

Extend `Rule` for a check you want to reuse.
Add an extension method, so it looks like a built-in check.

```dart
class SlugRule extends Rule<String> {
  SlugRule({super.message});

  @override
  String get name {
    return 'slug';
  }

  @override
  String get defaultMessage {
    return 'The {field} must be a slug';
  }

  @override
  bool check(String value, RuleContext context) {
    return RegExp(r'^[a-z0-9-]+$').hasMatch(value);
  }
}

extension SlugMethods on StringSchema {
  StringSchema slug({String? message}) {
    return use(SlugRule(message: message));
  }
}

v.string().min(3).slug();
```

- For a database check, extend `AsyncRule` and implement `checkAsync`.
- `RuleContext` gives `path`, `field`, `root` (the whole input) and `lookup('other.field')`.

## Messages

Each error has a `code`, like `required` or `min_length`. Dox finds the message in this order:

1. The message on the check: `.min(3, message: 'Too short')`.
2. `messages['path.code']`, like `email.required`.
3. `messages['code']`, like `required`.
4. The default English text.

Placeholders: `{field}`, `{value}`, and rule values like `{min}` and `{max}`.

```dart
// for the whole app
v.messages.setMessages(<String, String>{'required': 'Please fill in {field}'});

// for one call
createUser.safeParse(input, messages: MessageResolver(messages: <String, String>{
  'email.required': 'We need your email',
}));
```

For other languages, extend `MessageResolver` and override `resolve()`.

## Rule strings with `fromRules`

Do you already have rule strings? `v.fromRules()` turns them into a schema.

```dart
final ObjectSchema rules = v.fromRules(<String, String>{
  'email': 'required|email|max:255',
  'age': 'nullable|integer|min:18',
  'nickname': 'sometimes|required|string',
  'address.city': 'required',
  'products.*.name': 'required',
});

rules.parse(req.all());
```

- A missing field that is not `required` skips its other rules.
- `nullable`: `null` is fine. `sometimes`: skip everything when the field is missing.
- Each field stops at its first error, so there is one message per field.
- An unknown rule name throws an `ArgumentError` when the schema is built.

Add your own rule name:

```dart
v.registerRule('unique', (RuleDefinition definition) {
  return UniqueRule(table: definition.arg(0)); // 'unique:users'
});
```

## JSON Schema

Every schema can export JSON Schema (draft 2020-12, the one OpenAPI 3.1 uses).
Pass it to [OpenAPI](openapi.md) to document your API.

```dart
v.object(<String, Schema<Object?>>{
  'email': v.string().email().describe('Login email'),
  'age': v.int().min(18).nullable(),
}).strict().toJsonSchema();
```

```json
{
  "type": "object",
  "properties": {
    "email": { "type": "string", "format": "email", "description": "Login email" },
    "age": { "type": ["integer", "null"], "minimum": 18 }
  },
  "required": ["email", "age"],
  "additionalProperties": false
}
```

## Standard Schema

Every schema implements the [Standard Schema](https://standardschema.dev) interface (`StandardSchema`).
Code that only needs to validate can accept any `StandardSchema`, from Dox or from another library.

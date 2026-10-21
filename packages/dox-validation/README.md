# dox_validation

Schema validation for Dart, like [Zod](https://zod.dev).

- Fluent schemas with typed output.
- All problems come back at once, each with a path, a code and a message.
- Every schema implements the [Standard Schema](https://standardschema.dev) interface (`StandardSchema`).
- Every schema can export JSON Schema (draft 2020-12, OpenAPI 3.1) with `toJsonSchema()`.
- Laravel style string rules (`'required|email|max:255'`) still work with `v.fromRules()`.
- No dependencies.

## Quick start

```dart
import 'package:dox_validation/dox_validation.dart';

final ObjectSchema createUser = v.object(<String, Schema<Object?>>{
  'name': v.string().trim().min(3).max(50),
  'email': v.string().email(),
  'age': v.coerce.int().min(18).optional(),
  'role': v.enumOf<String>(<String>['admin', 'user']).defaultTo('user'),
  'tags': v.list(v.string()).max(5),
});

// Throws ValidationException when the input is not valid.
Map<String, dynamic> data = createUser.parse(input);

// Never throws for bad input.
ParseResult<Map<String, dynamic>> result = createUser.safeParse(input);
if (!result.success) {
  print(result.errors); // {'email': 'The email is not a valid email'}
  for (ValidationIssue issue in result.issues) {
    print('${issue.path} ${issue.code} ${issue.message}');
  }
}
```

### Schemas

| Schema | Notes |
| --- | --- |
| `v.string()` | `min`, `max`, `length`, `nonEmpty`, `email`, `url`, `uuid`, `ip`, `datetime`, `regex`, `startsWith`, `endsWith`, `includes`, `alpha`, `alphaDash`, `alphaNumeric`, `trim`, `toLowerCase`, `toUpperCase` |
| `v.int()`, `v.num()` | `min`, `max`, `gt`, `lt`, `positive`, `nonNegative`, `multipleOf` |
| `v.bool()` | |
| `v.date()` | `DateTime` only. `min`, `max` |
| `v.enumOf([...])`, `v.literal(x)` | |
| `v.list(item)` | `min`, `max`, `nonEmpty` |
| `v.object({...})` | `strict`, `passthrough`, `strip`, `pick`, `omit`, `extend`, `partial` |
| `v.map(values, keys: ...)` | any keys |
| `v.union([...])` | first match wins |
| `v.any()`, `v.file()` | `file()` takes a `FileInput`. `image`, `extensions` |

On every schema: `optional()`, `nullable()`, `nullish()`, `defaultTo(x)`,
`transform(fn)`, `refine(fn)`, `refineAsync(fn)`, `superRefine(fn)`,
`use(rule)`, `describe(text)`, `example(x)`.

- `optional()`: the key may be missing. `null` is still an error.
- `nullable()`: the value may be `null`. The key must be there.
- `nullish()`: both.
- `defaultTo(x)`: `default` is a reserved word in Dart, so the name is different.

### Coercion

Query strings and form data are text. `v.coerce` turns text into the right type first.

```dart
v.coerce.int().parse('42');       // 42
v.coerce.num().parse('4.5');      // 4.5
v.coerce.bool().parse('on');      // true  (true/1/yes/on, false/0/no/off)
v.coerce.date().parse('2024-01-31');
v.coerce.string().parse(5);       // '5'
```

### Async checks

```dart
final StringSchema email = v.string().email().refineAsync(
  (String value) async {
    return !(await users.emailExists(value));
  },
  message: 'The {field} is already taken',
);

await email.parseAsync('a@dox.dev');
```

`parse()` throws a `StateError` when a schema has async checks. Use `parseAsync()` or `safeParseAsync()`.

### Object checks

```dart
final ObjectSchema signUp = v.object(<String, Schema<Object?>>{
  'password': v.string().min(8),
  'confirm': v.string(),
}).refine((Map<String, dynamic> data) {
  return data['password'] == data['confirm'];
}, message: 'Passwords do not match', path: <Object>['confirm']);
```

## Custom rules

Extend `Rule` for a check you want to reuse. Add an extension method to make it look like a built-in method.

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

  // Optional: shown in toJsonSchema().
  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'pattern': r'^[a-z0-9-]+$'};
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
- Add values for the message with the `params` getter, like `{'count': 3}` for `{count}`.
- `RuleContext` gives `path`, `field`, `root` (the whole input) and `lookup('other.field')`.

## Messages

Each issue has a `code`, like `required` or `min_length` (see `IssueCodes`).
Messages are found in this order:

1. The message on the rule: `.min(3, message: 'Too short')`.
2. `messages['path.code']`, like `email.required` or `items.*.name.required`.
3. `messages['code']`, like `required`.
4. The default English text (see `DefaultMessages`).

Placeholders: `{field}` (last key in the path), `{value}`, and rule values like `{min}` and `{max}`. Old dox `%s` placeholders also work.

```dart
// Global messages
v.messages.setMessages(<String, String>{'required': 'Please fill in {field}'});

// For one call
createUser.safeParse(input, messages: MessageResolver(messages: <String, String>{
  'email.required': 'We need your email',
}));

// For i18n, extend MessageResolver and override resolve().
v.messages = MyGermanResolver();
```

## Laravel style rules

`v.fromRules()` builds an `ObjectSchema` from the rule strings that dox apps already use.

```dart
final ObjectSchema rules = v.fromRules(<String, String>{
  'email': 'required|email|max:255',
  'age': 'nullable|integer|min:18',
  'nickname': 'sometimes|required|string',
  'address.city': 'required',
  'products.*.name': 'required',
}, messages: <String, String>{
  'email.required': 'Email please',
});

rules.parse(request.all());
```

How it works:

- A missing or `null` field that is not `required` skips all its other rules.
- Empty text that is not `required` also skips other rules.
- `nullable`: `null` is fine. It also marks the field as nullable in JSON Schema.
- `sometimes`: skip everything when the field is missing, even `required`.
- Each field stops at its first failed rule, so there is one message per field.
- Dotted keys make nested objects. `*` makes a list.
- The output has only the fields that have rules. The values are not changed.
- An unknown rule name throws an `ArgumentError` when the schema is built.

Rules: `required`, `required_if`, `required_if_not`, `string`, `numeric`, `integer`, `double`, `boolean`, `array`, `json`, `date`, `email`, `ip`, `url`, `uuid`, `alpha`, `alpha_dash`, `alpha_numeric`, `min_length`, `max_length`, `length_between`, `between`, `greater_than`, `less_than`, `min`, `max`, `in`, `not_in`, `start_with`, `end_with`, `confirmed`, `image`, `file`, plus the flags `nullable`, `sometimes`, `bail`.

`min` and `max` check text length when the field also has `string`, list size for lists, and the number value otherwise.

Add your own rule name:

```dart
v.registerRule('unique', (RuleDefinition definition) {
  return UniqueRule(table: definition.arg(0)); // 'unique:users'
});
```

For dependency injection, make your own `Validator(registry: RuleRegistry.withDefaults())` instead of using the global `v`.

## JSON Schema

```dart
v.object(<String, Schema<Object?>>{
  'email': v.string().email().describe('Login email'),
  'age': v.int().min(18).nullable(),
  'role': v.enumOf<String>(<String>['admin', 'user']).defaultTo('user'),
}).strict().toJsonSchema();
```

```json
{
  "type": "object",
  "properties": {
    "email": { "type": "string", "format": "email", "description": "Login email" },
    "age": { "type": ["integer", "null"], "minimum": 18 },
    "role": { "type": "string", "enum": ["admin", "user"], "default": "user" }
  },
  "required": ["email", "age"],
  "additionalProperties": false
}
```

`v.fromRules(...)` schemas export JSON Schema too.

## Standard Schema

Every schema implements `StandardSchema<Object?, O>`:

```dart
abstract class StandardSchema<I, O> {
  String get vendor;   // 'dox'
  int get version;     // 1
  FutureOr<StandardResult<O>> validate(Object? value);
}
```

Code that only needs to validate can accept any `StandardSchema`, from dox or from another library.

- `validate` returns a plain result for sync schemas and a `Future` for async ones.
- On success, `issues` is an empty list (the JS spec uses `undefined`).

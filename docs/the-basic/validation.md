---
icon: lucide/list-checks
---

# Validation

This page shows how to check request input with typed DTO classes.

Write a class with `@Dto()`. Ask for it in your controller.
Dox reads the request, checks it, and gives you a typed object.
When the input is wrong, Dox answers `422` with the errors. Your controller does not run.

```dart title="lib/app/http/dtos/create_user.dto.dart"
import 'package:dox_core/dox_core.dart';

part 'create_user.dto.g.dart';

@Dto()
class CreateUser {
  @Trim()
  @Length(min: 3, max: 50)
  final String name;

  @Email()
  final String email;

  @Min(18)
  final int? age; // nullable, so optional

  const CreateUser({required this.name, required this.email, this.age});

  static const DtoSchema<CreateUser> schema = $CreateUserDto;
}
```

```dart title="lib/app/http/controllers/user.controller.dart"
class UserController {
  Future<User> store(CreateUser body) async {
    // body is already checked
    User user = User()
      ..name = body.name
      ..email = body.email;
    await user.save();
    return user;
  }
}
```

## Setup

You do this once per app.

1. Make a DTO with `dox make:dto CreateUser`. It writes `lib/app/http/dtos/create_user.dto.dart`.
2. Run the generator: `dox build_runner:build` (or `dox build_runner:watch`).
   It writes a `.dto.g.dart` file next to each DTO, and one list of all DTOs in `lib/generated/dtos.g.dart`.
3. Give that list to the app:

```dart title="lib/config/app.dart"
import 'package:my_app/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos, // from lib/generated/dtos.g.dart
  // ...
);
```

Dox uses no reflection, so it needs this list to find your DTOs. Without it, the server stops at start with a clear error.

## Use a DTO

Add a parameter with the DTO type. Dox checks the request before your method runs.

```dart
Future<User> store(CreateUser body) async { ... }

// with the request and a path param
Future<User> update(DoxRequest req, int id, UpdateUser body) async { ... }
```

Or check inside the method. `req.validate<T>()` returns the object, or throws the `422` error.

```dart
CreateUser data = await req.validate<CreateUser>();
```

See [Controller: parameters](controller.md#parameters) for the full rules.

## Required and optional

The Dart type decides. You do not write `required` or `nullable`.

| Field | Key missing | Value `null` |
| --- | --- | --- |
| `final String name;` | error `required` | error `required` |
| `final int? age;` | `null` | `null` |
| `final Role role;` with `this.role = Role.user` | `Role.user` | error `required` |

- Rules on an optional field run only when it has a value.
- A default value is used only when the key is missing. The rules do not check it.
- **An empty string counts as missing.** So a required `String` rejects `""`. Add `@AllowEmpty()` to keep `""`.

### Missing or `null`? (for PATCH)

A `T?` field gives `null` for both. To know the difference, use `Maybe<T>`:

```dart
@Length(max: 500)
final Maybe<String?> bio; // default: const Maybe.missing()

// in the controller
if (body.bio.isPresent) {
  user.bio = body.bio.value; // can be null: the client cleared it
}
```

## Types

| Dart type | JSON | Query and form data |
| --- | --- | --- |
| `String`, `int`, `double`, `num`, `bool` | the same JSON type | text, converted |
| `DateTime` | an ISO 8601 string | the same |
| an `enum` | the name, like `"admin"` | the same |
| `RequestFile` | not allowed | a file part |
| a `@Dto` class | an object | bracket keys: `address[city]` |
| `List<T>` | an array | `tags=a&tags=b` or `tags[]=a` |
| `Map<String, T>` | an object | bracket keys: `meta[color]` |

JSON is strict: `"18"` is not an `int`. Query and form data are text, so Dox converts them.
Every detail is in [Types in detail](validation-rules.md#types-in-detail).

## Where the data comes from

| Request | Dox reads |
| --- | --- |
| `GET`, `HEAD`, `DELETE` | the query string |
| `POST`, `PUT`, `PATCH` | the body (JSON, form or multipart) |

Dox reads **one** source. It never mixes the query and the body.
To choose the source yourself:

```dart
@Dto(source: Source.query) // on the DTO
class SearchUsers { ... }

await req.validate<SearchUsers>(source: Source.query); // for one call
```

Path params are not part of a DTO. Ask for them as controller parameters, like `int id`.

## Keys

The input key is the field name in snake_case: `firstName` reads `first_name`.

```dart
final String firstName; // key: first_name

@Name('emailAddress')
final String email; // key: emailAddress
```

- `@Dto(keyCase: KeyCase.field)` uses the field names as they are.
- Unknown keys are dropped. With `@Dto(strict: true)`, an unknown key is an error.

## Rules

Put rules on a field as annotations. They run from top to bottom. The first rule that fails gives the error.

```dart
@Trim()
@Lowercase()
@Email()
@MaxLength(255)
final String email;
```

| Kind | Annotations |
| --- | --- |
| Text | `@Length`, `@MinLength`, `@MaxLength`, `@Email`, `@Url`, `@Uuid`, `@Ip`, `@Regex`, `@In`, `@NotIn`, `@StartsWith`, `@EndsWith`, `@Alpha`, `@AlphaNumeric`, `@AlphaDash` |
| Change text | `@Trim`, `@Lowercase`, `@Uppercase`, `@AllowEmpty` |
| Numbers | `@Min`, `@Max`, `@Range`, `@Positive`, `@GreaterThan`, `@LessThan`, `@In`, `@NotIn` |
| Lists | `@MinItems`, `@MaxItems`, `@UniqueItems` |
| Dates | `@After`, `@Before` |
| Files | `@MaxSize`, `@Mimes`, `@Image` |
| Database | `@Unique`, `@Exists` |

Every rule, with its error code and message, is in [Validation rules](validation-rules.md).

- A rule on a list checks each item: `@Email()` on a `List<String>`. Only the list rules check the list itself.
- For a few allowed values, use a Dart `enum`, or `@In(<String>['draft', 'published'])`.

## Nested objects and lists

A field can be another `@Dto` class, or a list of them.

```dart
@Dto()
class CreateOrder {
  final Address address;

  @MinItems(1)
  final List<OrderItem> items;

  const CreateOrder({required this.address, required this.items});

  static const DtoSchema<CreateOrder> schema = $CreateOrderDto;
}
```

`Address` and `OrderItem` are `@Dto` classes too. An error in a nested value has a path key, like `items.1.quantity`.

## Files

A `RequestFile` field reads a file from `multipart/form-data`.

```dart
@Image()
@MaxSize('2MB')
final RequestFile avatar;

@Mimes(<String>['pdf', 'docx'])
final List<RequestFile> documents;
```

Dox checks the real file type from its first bytes. It does not trust the file name or the client.
To save the file, see [File upload](../guides/file-upload.md).

## Checks across fields: `validate()`

Add a `validate(DtoErrors errors)` method to the DTO. Dox calls it after all field rules passed.

```dart
void validate(DtoErrors errors) {
  if (password != passwordConfirmation) {
    errors.add('password_confirmation', 'The passwords do not match');
  }
}
```

- The key is the input key (snake_case). Use `_root` for an error about the whole body.
- `errors.has(key)` tells you if a key already has an error.
- The method can be `async`. Do not throw for bad input. Add an error.

## Database rules: `@Unique` and `@Exists`

These read the database, so they run last.

```dart
@Unique('users', column: 'email')
final String email;

@Exists('teams') // column defaults to id
final int teamId;
```

For an update, skip the row you are updating with `ignoreParam`:

```dart
// PUT /users/{id}
@Unique('users', column: 'email', ignoreParam: 'id')
final String email;
```

All options are in [Validation rules: database](validation-rules.md#database).
The full order of checks is in [The order of checks](validation-rules.md#the-order-of-checks).

## The error response

When a check fails, Dox answers `422` with one message per field:

```json
{
  "email": "The email is not a valid email",
  "tags.0": "The tags may not be greater than 20 characters",
  "items.1.quantity": "The quantity must be greater than 0"
}
```

The key is the path to the value, with the input keys. List items use the index.

## Messages

Change a message in one of these places. The first one wins.

1. On the rule: `@Email(message: 'Please check your email')`.
2. On the DTO, by code or by `key.code`:

```dart
@Dto(messages: <String, String>{
  'email.required': 'We need your email',
  'integer': 'The {field} must be a number',
})
```

3. For the whole app, with a `MessageResolver`. Use it for other languages:

```dart
class AppMessages extends MessageResolver {
  static const Map<String, Map<String, String>> _texts = <String, Map<String, String>>{
    'th': <String, String>{'required': 'กรุณากรอก {field}'},
  };

  @override
  String resolve(MessageRequest request) {
    String? template = _texts[request.locale]?[request.code]; // locale from Accept-Language
    if (template == null) {
      return super.resolve(request);
    }
    return format(template, request.params);
  }
}

AppConfig appConfig = AppConfig(
  validationMessages: AppMessages(),
  // ...
);
```

Placeholders: `{field}` (the last key), `{value}`, and rule values like `{min}` and `{max}`.

## Custom rules

Extend `Rule<T>`. `T` is the field type (or the item type, for a list).

```dart
class Slug extends Rule<String> {
  const Slug({super.message});

  @override
  String get name {
    return 'slug'; // the error code
  }

  @override
  String get defaultMessage {
    return 'The {field} must be a slug';
  }

  @override
  bool check(String value, RuleContext context) {
    return _pattern.hasMatch(value);
  }

  static final RegExp _pattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
}

// use it
@Slug()
final String slug;
```

- A rule with values: add `final` fields and override `params`. They become placeholders.
- `context.lookup('other.key')` reads another input value.
- A rule that needs the database: extend `AsyncRule<T>` and write `checkAsync`.

## Dynamic input

When the shape is known only at runtime (like form fields from the database), use a fluent schema:

```dart
Map<String, dynamic> data = await req.validateSchema(v.object(fields));
```

See [Fluent schemas](../packages/validation.md#fluent-schemas-for-dynamic-input). Use a DTO for everything else.

## Testing

A DTO is a normal Dart class. Make one directly to skip the checks:

```dart
CreateUser input = const CreateUser(name: 'Ann', email: 'ann@dox.dev');
```

To test the checks, use `safeValidateMap`. It never throws:

```dart
ParseResult<CreateUser> result = await CreateUser.schema.safeValidateMap(<String, dynamic>{
  'name': 'A',
  'email': 'not-an-email',
});

expect(result.success, isFalse);
expect(result.errors['email'], 'The email is not a valid email');
```

- `validateMap` does the same, but returns the object or throws.
- `source: Source.query` reads the map like a query string. `params: {'id': '5'}` gives path params.
- `@Unique` and `@Exists` need a test database.

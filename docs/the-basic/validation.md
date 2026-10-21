# Validation

Write a class with `@Dto()`. Ask for it in your controller.
Dox reads the request, checks it, and gives you a typed object.
When the input is wrong, Dox answers `422` with the errors. Your controller does not run.

```dart
import 'package:dox_core/dox_core.dart';

part 'create_user.dto.g.dart';

enum Role { admin, user }

@Dto()
class CreateUser {
  @Length(min: 3, max: 50)
  @Trim()
  final String name;

  @Email()
  final String email;

  @Min(18)
  final int? age; // nullable = optional

  final Role role; // must be "admin" or "user"

  @MaxItems(5)
  final List<String> tags;

  const CreateUser({
    required this.name,
    required this.email,
    this.age,
    this.role = Role.user,
    this.tags = const <String>[],
  });

  static const DtoSchema<CreateUser> schema = $CreateUserDto;
}
```

```dart
class UserController {
  Future<User> store(CreateUser body) async {
    // body is already checked. body.age is an int?, body.role is a Role.
    User user = User()
      ..name = body.name
      ..email = body.email;
    await user.save();
    return user;
  }
}
```

Then run the generator:

```bash
dart run build_runner build
```

## Setup

You do this once per app.

1. Put DTOs in `lib/app/http/dtos/`. Name the file `<name>.dto.dart`.
   `dox create:dto CreateUser` makes `lib/app/http/dtos/create_user.dto.dart` for you.
2. Each DTO file has `part '<name>.dto.g.dart';` and the `schema` line:
   `static const DtoSchema<CreateUser> schema = $CreateUserDto;`
3. Run `dart run build_runner build` (or `dox build_runner:watch`).
   It writes a `.dto.g.dart` file next to each DTO and one list of all DTOs in `lib/dtos.g.dart`.
4. Give that list to the app in `lib/config/app.dart`:

```dart
import 'package:my_app/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos, // from lib/dtos.g.dart
  // ...
);
```

!!! info "Why the list?"
    Dox does not use `dart:mirrors`. So it can not find a class by its name at runtime.
    The generated list tells Dox which classes are DTOs. You never edit it by hand.

**What the generator makes for each DTO** (no reflection, works with `dox build` AOT):

- the checks for every field,
- the code that turns the input map into your class,
- a JSON Schema, used by the [OpenAPI docs](../packages/openapi.md).

## Use a DTO

### As a controller parameter

Add a parameter with the DTO type. Dox checks the request before your method runs.

```dart
Future<User> store(CreateUser body) async { ... }

// with path params and the request
Future<User> update(DoxRequest req, int id, UpdateUser body) async { ... }
```

See [Controller: parameters](controller.md#parameters) for the full rules.

### Inside a method

`req.validate<T>()` does the same work. It returns the object or throws the `422` error.

```dart
Future<User> store(DoxRequest req) async {
  CreateUser data = await req.validate<CreateUser>();
  // ...
}
```

`req.validate<T>()` is always async. Always `await` it.

## Required and optional

The Dart type decides. You do not write `required` or `nullable`.

| Field | Missing key | `null` | Result |
| --- | --- | --- | --- |
| `final String name;` (no default) | error `required` | error `required` | required |
| `final int? age;` | `null` | `null` | optional |
| `final Role role;` with `this.role = Role.user` | the default | error `required` | optional, has a default |
| `final Maybe<String?> bio;` with `this.bio = const Maybe.missing()` | `isPresent == false` | `isPresent == true`, `value == null` | optional, knows "missing" from `null` |

Rules:

- **Required** = not nullable and no default in the constructor.
- **Optional** = nullable (`T?`), or has a default.
- A default is used only when the key is missing. A default value is not checked by the rules.
- `null` is never allowed for a non-nullable field, even when it has a default.
- **An empty string counts as missing.** After `@Trim()`, `""` is treated like a missing key, in JSON, query and form data.
  So a required `String` rejects `""` and `"   "` (with `@Trim()`). A `String?` gets `null`.
  Add `@AllowEmpty()` to keep `""` as a real value.
- Rules on an optional field run only when it has a value.

### Missing or `null`? (for PATCH)

A `T?` field gives `null` for both a missing key and a `null` value.
When you must know the difference, use `Maybe<T>`. Its default must be `const Maybe.missing()`.

```dart
@Dto()
class UpdateUser {
  @Length(max: 500)
  final Maybe<String?> bio;

  const UpdateUser({this.bio = const Maybe.missing()});

  static const DtoSchema<UpdateUser> schema = $UpdateUserDto;
}

// in the controller
if (body.bio.isPresent) {
  user.bio = body.bio.value; // can be null: the client cleared it
}
```

Rules on a `Maybe<T>` field check `value` when it is present and not `null`.

## Types

| Dart type | JSON | Query and form data (text) |
| --- | --- | --- |
| `String` | a string | as is |
| `int` | a whole number (`18` or `18.0`) | `"18"` |
| `double` | any number (`18` becomes `18.0`) | `"4.5"`, `"18"` |
| `num` | any number | `"18"`, `"4.5"` |
| `bool` | `true` / `false` | `true`, `1`, `yes`, `on` / `false`, `0`, `no`, `off` (any case) |
| `DateTime` | an ISO 8601 string | the same |
| an `enum` | the name, like `"admin"` | the same |
| `RequestFile` | not allowed | a file part in `multipart/form-data` |
| a `@Dto` class | an object | bracket keys, like `address[city]` |
| `List<T>` | an array | repeated keys `tags=a&tags=b`, or `tags[]=a&tags[]=b` |
| `Map<String, T>` | an object with any keys | bracket keys, like `meta[color]` |
| `Object?`, `dynamic`, `Map<String, dynamic>` | any JSON, not checked | any text, not checked |

**JSON is strict.** In a JSON body, `"18"` is not an `int`. You get the error `integer`.
**Query and form data are text,** so Dox turns the text into the field type first.
If it can not, you get the type error (like `integer` or `boolean`).

More details:

- `int` never takes a fraction. `"4.5"` or `4.5` gives the error `integer`.
- `DateTime` takes `2024-01-31` or `2024-01-31T10:00:00Z`. A value without a time zone is read as UTC.
  The result is always UTC (`isUtc == true`). A number (timestamp) is not allowed.
- An `enum` matches the name exactly. `"Admin"` does not match `Role.admin`.
- In query and form data, one value for a `List<T>` field gives a list with one item.
- In bracket keys, list indexes are sorted and packed: `items[3]` alone gives a list with one item.
  A list can have at most 1000 items, and keys can nest at most 10 levels. More gives `422`.
- The generator stops with an error for any other type.

## Where the data comes from

| Request | Dox reads |
| --- | --- |
| `GET`, `HEAD`, `DELETE` | the query string |
| `POST`, `PUT`, `PATCH` | the body |

Dox reads **one** source. It never mixes the query and the body.
So a query value can not overwrite a body value.

The body can be:

- JSON: `application/json` (or any `+json` type). Strict types.
- `application/x-www-form-urlencoded`: text, converted.
- `multipart/form-data`: text, converted. Files go to `RequestFile` fields.

Other content types get `415 Unsupported Media Type`. A body that is not valid JSON gets `400 Bad Request`.
A JSON body that is not an object (like `[1, 2]`) gets `422` with the key `_root`.

### Choose the source

Set it on the DTO, when this DTO is always read from one place:

```dart
@Dto(source: Source.query) // also for POST
class SearchUsers { ... }
```

Or set it for one call:

```dart
SearchUsers filter = await req.validate<SearchUsers>(source: Source.query);
```

`Source.auto` (the default) uses the table above. `Source.query` and `Source.body` force one source.

### Path params

Path params are not part of a DTO. Ask for them as typed controller parameters:

```dart
Route.put('/users/{id}', controller.update);

Future<User> update(int id, UpdateUser body) async { ... }
```

A path param that does not fit its type (like `abc` for `int id`) answers `404`.
See [Controller: parameters](controller.md#parameters).

## Keys: snake_case by default

The JSON key is the field name in snake_case, the same as the [ORM](../database/model/index.md).
`firstName` reads `first_name`.

```dart
@Dto()
class SignUp {
  final String firstName; // key: first_name

  @Name('emailAddress')
  final String email; // key: emailAddress

  const SignUp({required this.firstName, required this.email});

  static const DtoSchema<SignUp> schema = $SignUpDto;
}
```

To use the field names as they are (camelCase), set it on the DTO:

```dart
@Dto(keyCase: KeyCase.field) // firstName reads firstName
```

Error keys always use the input key (`first_name`), not the Dart name.

## Unknown keys

Keys that the DTO does not have are dropped. You never see them.

With `@Dto(strict: true)`, an unknown key is an error:

```json
{ "is_admin": "The is_admin field is not allowed" }
```

## Rules

Put rules on a field as annotations. A field can have many. They run from top to bottom.
The first rule that fails gives the error for that field.

```dart
@Trim()
@Lowercase()
@Email()
@MaxLength(255)
final String email;
```

Every rule is in the [rules reference](validation-rules.md). The short list:

| Kind | Annotations |
| --- | --- |
| Text | `@Length`, `@MinLength`, `@MaxLength`, `@Email`, `@Url`, `@Uuid`, `@Ip`, `@Regex`, `@In`, `@NotIn`, `@StartsWith`, `@EndsWith`, `@Alpha`, `@AlphaNumeric`, `@AlphaDash` |
| Change text | `@Trim`, `@Lowercase`, `@Uppercase`, `@AllowEmpty` |
| Numbers | `@Min`, `@Max`, `@Range`, `@Positive`, `@GreaterThan`, `@LessThan`, `@In`, `@NotIn` |
| Lists | `@MinItems`, `@MaxItems`, `@UniqueItems` |
| Dates | `@After`, `@Before` |
| Files | `@MaxSize`, `@Mimes`, `@Image` |
| Database | `@Unique`, `@Exists` (from `dox_orm`) |
| Keys | `@Name` |

!!! tip "Rules on a list check each item"
    `@Email()` on a `List<String>` checks every item. The error key is `emails.2`.
    Only `@MinItems`, `@MaxItems` and `@UniqueItems` check the list itself.

The generator stops with an error when a rule does not fit the type, like `@Email()` on an `int`.

!!! note "Name clash"
    `dox_core` exports the rule names (`Uuid`, `Name`, `Range`, `Image`, ...).
    A file that also imports a package with the same name, like `package:uuid`, gets an "ambiguous import" error.
    Fix it with `hide`: `import 'package:dox_core/dox_core.dart' hide Uuid;`.
    `dox_orm` has a `Schema` class too: `import 'package:dox_orm/dox_orm.dart' hide Schema;`.

### Enums or `@In`

Use a Dart `enum` when you can. The allowed values are the enum names.
Use `@In([...])` for a plain `String` or `int` with a few allowed values:

```dart
final Role role;              // "admin" or "user"

@In(<String>['draft', 'published'])
final String status;
```

## Nested objects and lists

A field can be another `@Dto` class, or a list of them.

```dart
@Dto()
class Address {
  final String city;

  @Length(min: 5, max: 5)
  final String postCode;

  const Address({required this.city, required this.postCode});

  static const DtoSchema<Address> schema = $AddressDto;
}

@Dto()
class OrderItem {
  final String name;

  @Positive()
  final int quantity;

  const OrderItem({required this.name, required this.quantity});

  static const DtoSchema<OrderItem> schema = $OrderItemDto;
}

@Dto()
class CreateOrder {
  final Address address;

  @MinItems(1)
  final List<OrderItem> items;

  const CreateOrder({required this.address, required this.items});

  static const DtoSchema<CreateOrder> schema = $CreateOrderDto;
}
```

```json
{
  "address": { "city": "Bangkok", "post_code": "10110" },
  "items": [
    { "name": "Shoes", "quantity": 2 },
    { "name": "Socks", "quantity": 0 }
  ]
}
```

Error: `{"items.1.quantity": "The quantity must be greater than 0"}`.

A nested DTO has its own options (`keyCase`, `strict`). A nullable nested field (`Address?`) is optional.

## Files

A `RequestFile` field reads a file from `multipart/form-data`.

```dart
@Dto()
class UploadAvatar {
  @Image()
  @MaxSize('2MB')
  final RequestFile avatar;

  @MaxItems(5)
  @Mimes(<String>['pdf', 'docx'])
  final List<RequestFile> documents; // documents[] or repeated documents

  const UploadAvatar({required this.avatar, this.documents = const <RequestFile>[]});

  static const DtoSchema<UploadAvatar> schema = $UploadAvatarDto;
}
```

- Dox reads the first bytes of the file to find its real type. The file name and the client content type are not trusted.
- `@Image()` allows `jpg`, `jpeg`, `png`, `gif`, `webp` and `bmp`. Not `svg`, because an SVG can hold scripts.
- A text field sent where a file is expected gives the error `file`.
- Save the file before you return. See [Request: form data](request.md#form-data-file).

## Checks across fields: `validate()`

Add a method `validate(DtoErrors errors)` to the DTO. Dox calls it after every field rule passed.
At that point, all fields have their typed values.

```dart
@Dto()
class SignUp {
  @MinLength(8)
  final String password;

  final String passwordConfirmation;

  final DateTime? startsAt;
  final DateTime? endsAt;

  const SignUp({
    required this.password,
    required this.passwordConfirmation,
    this.startsAt,
    this.endsAt,
  });

  void validate(DtoErrors errors) {
    if (password != passwordConfirmation) {
      errors.add('password_confirmation', 'The passwords do not match');
    }
    if (startsAt != null && endsAt != null && !endsAt!.isAfter(startsAt!)) {
      errors.add('ends_at', 'The end must be after the start');
    }
  }

  static const DtoSchema<SignUp> schema = $SignUpDto;
}
```

The exact API:

- The method is named `validate`. It takes one `DtoErrors` and returns `void` or `Future<void>`.
- `errors.add(String key, String message)` adds an error. `key` is the input key (snake_case), not the Dart name.
  The message is used as it is (no placeholders, no message resolver).
- `errors.has(String key)` is `true` when that key already has an error.
- Use the key `_root` for an error that is not about one field.
- In a nested DTO, keys are relative. Dox adds the parent path: `address.post_code`.
- Do not throw for bad input. Add an error.

## Database rules: `@Unique` and `@Exists`

These come from `dox_orm`. They read the database, so they run last.

```dart
import 'package:dox_orm/dox_orm.dart' hide Schema;

@Dto()
class CreateUser {
  @Email()
  @Unique('users', column: 'email')
  final String email;

  @Exists('teams') // column defaults to id
  final int teamId;

  @Exists('tags')
  final List<int> tagIds; // checks every item in one query

  const CreateUser({required this.email, required this.teamId, this.tagIds = const <int>[]});

  static const DtoSchema<CreateUser> schema = $CreateUserDto;
}
```

| Annotation | Passes when |
| --- | --- |
| `@Unique(table, {column})` | no row has this value. `column` defaults to the input key. |
| `@Exists(table, {column})` | a row has this value. `column` defaults to `id`. |

For an update, skip the row you are updating. `ignoreParam` names a path param:

```dart
// PUT /users/{id}
@Unique('users', column: 'email', ignoreParam: 'id') // WHERE id != {id}
final String email;
```

- `ignoreColumn:` sets the id column. Default `id`.
- `connection:` uses another `dox_orm` connection. Default: the default connection.
- Soft-deleted rows count too.
- Upper or lower case: this depends on your database collation.
- On a `List<T>` field, each item is checked. All items use one `WHERE IN` query.

## The order of checks

1. Read the input and convert types. Change text (`@Trim`, `@Lowercase`, `@Uppercase`). Missing required fields.
2. The field rules, top to bottom.
3. The `validate()` method (nested DTOs first, then the parent).
4. Async rules (`@Unique`, `@Exists`, your `AsyncRule`), one at a time, in field order.

**Each step runs only when the step before it had no errors.**
So the database is never asked about input that is already wrong.

- Steps 1 and 2 run per DTO. A nested DTO checks its own types first, then its own rules.
  So one answer can have a type error in `address` and a rule error in `items.1`.
- Inside one step, Dox collects the errors of all fields.
- A default value is not checked by the field rules. (Async rules check the final value.)

## The error response

When a check fails, Dox answers `422 Unprocessable Entity` with a flat JSON object.
The key is the path to the value. The value is one message (the first error of that field).

```json
{
  "email": "The email is not a valid email",
  "tags.0": "The tags may not be greater than 20 characters",
  "address.city": "The city is required",
  "items.1.quantity": "The quantity must be greater than 0"
}
```

- Paths use dots. List items use the index: `tags.0`.
- Paths use the input keys (`post_code`), after `@Name` and `keyCase`.
- `_root` is for errors about the whole body.

## Messages

Every rule has a default English message. See the [rules reference](validation-rules.md).

**Placeholders:** `{field}` is the last key of the path (for list items: the list key).
`{value}` is the input value. Rules add their own, like `{min}` and `{max}`.

### On one rule

Every annotation takes `message:`.

```dart
@Email(message: 'Please check your email')
@Length(min: 3, message: 'At least {min} letters, please')
```

### On one DTO

`@Dto(messages: ...)` sets messages by code, or by `key.code`.
Use it for messages that have no annotation, like `required` or a type error.

```dart
@Dto(messages: <String, String>{
  'email.required': 'We need your email',
  'required': 'Please fill in {field}',
  'integer': 'The {field} must be a number',
})
```

### For the whole app, and other languages

Dox finds a message in this order:

1. `message:` on the annotation.
2. `@Dto(messages:)`: first `key.code` (like `email.required`), then `code`.
3. The app message resolver.
4. The default English text.

For other languages, extend `MessageResolver` and set it in the config.
`request.locale` is the first language in the `Accept-Language` header, like `th`. It is `null` when there is none.

```dart
class AppMessages extends MessageResolver {
  static const Map<String, Map<String, String>> _texts = <String, Map<String, String>>{
    'th': <String, String>{'required': 'กรุณากรอก {field}'},
  };

  @override
  String resolve(MessageRequest request) {
    String? template = _texts[request.locale]?[request.code];
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

`MessageRequest` has `code`, `path`, `params`, `fallback`, `customMessage` and `locale`.

## Custom rules

A rule is a class that extends `Rule<T>`. It needs a `const` constructor, so you can use it as an annotation.
`T` is the field type (or the item type, for a list).

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

@Dto()
class CreatePost {
  @Slug()
  final String slug;

  const CreatePost({required this.slug});

  static const DtoSchema<CreatePost> schema = $CreatePostDto;
}
```

- A rule with values: add `final` fields and override `params`. They become placeholders.
- `RuleContext` gives `path`, `field`, `root` (the whole input) and `lookup('other.key')`.
- Override `toJsonSchema()` to add JSON Schema keys, like `{'pattern': '^[a-z0-9-]+$'}`.
- A check that needs the database: extend `AsyncRule<T>` and implement `Future<bool> checkAsync(T value, RuleContext context)`.
  It runs in step 4 of [the order of checks](#the-order-of-checks).

```dart
class MinValue extends Rule<int> {
  const MinValue(this.min, {super.message});

  final int min;

  @override
  String get name {
    return 'min_value';
  }

  @override
  String get defaultMessage {
    return 'The {field} must be at least {min}';
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'min': min};
  }

  @override
  bool check(int value, RuleContext context) {
    return value >= min;
  }
}
```

## Dynamic input: fluent schemas

Some input has a shape you only know at runtime, like custom form fields from the database.
For that, build a schema with `v.object(...)` and use `req.validateSchema()`. It returns a `Map`.

```dart
Map<String, Schema<Object?>> fields = <String, Schema<Object?>>{};
for (FormField f in form.fields) {
  fields[f.key] = f.required ? v.string().min(1) : v.string().optional();
}

Map<String, dynamic> data = await req.validateSchema(v.object(fields));
```

Use a DTO for everything else. See [`dox_validation`](../packages/validation.md#fluent-schemas-for-dynamic-input).

## Testing

**Make a DTO directly.** It is a normal Dart class. This skips all checks.

```dart
CreateUser input = const CreateUser(name: 'Ann', email: 'ann@dox.dev');
await userService.create(input);
```

**Check a map** with the rules, like a request would:

```dart
CreateUser user = await CreateUser.schema.validateMap(<String, dynamic>{
  'name': 'Ann',
  'email': 'ann@dox.dev',
});
expect(user.role, Role.user);
```

**Check the errors** with `safeValidateMap`. It never throws.

```dart
ParseResult<CreateUser> result = await CreateUser.schema.safeValidateMap(<String, dynamic>{
  'name': 'A',
  'email': 'not-an-email',
});

expect(result.success, isFalse);
expect(result.errors, <String, String>{
  'name': 'The name must be between 3 and 50 characters',
  'email': 'The email is not a valid email',
});
```

Options of both methods:

- `source: Source.query` reads the map like a query string (text is converted). Default: `Source.body` with JSON types.
- `params: {'id': '5'}` gives path params, for `@Unique(ignoreParam: 'id')`.

`@Unique` and `@Exists` need a database. Use a test database, or test those fields in an integration test.

## Not in 3.0

- A DTO can not extend another class, and can not be generic. The generator stops with an error.
- An enum value is always its Dart name. Custom wire values (like `"ADMIN"` for `Role.admin`) are not supported.

## Performance

- The generator writes plain Dart code for each DTO. No reflection, no rule strings to parse.
- A check is a few `if` statements per field. Regexes are compiled once.
- Dox finds the DTO for a route once, then keeps it.
- It works with `dox build` (AOT).

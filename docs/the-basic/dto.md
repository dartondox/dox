---
icon: lucide/package
---

# DTOs

A DTO is a typed Dart class that describes the input of a request, so your controller gets checked data instead of a raw map.

DTO means "data transfer object". You write a class with `@Dto()` and give each field a Dart type and some [rules](validation.md#rules). When you ask for the class in a controller, Dox reads the request, converts the values to your types, and checks the rules. Your method gets a typed object. When the input is wrong, the client gets `422`, and your method does not run.

You write the input shape once, and Dox uses it in many places: the request body, the query string, file uploads, the [OpenAPI docs](#openapi-docs), [MCP tools](#mcp-tools) and even a [Flutter app](#sharing-with-flutter).

## Creating a DTO

Use the `make:dto` command. It writes a DTO with one `name` field to `lib/app/dtos/<name>/<name>.dto.dart`:

```bash
dox make:dto CreateUser
```

A DTO uses generated code, so run the generator after you create or change one. It writes a `.dto.g.dart` file next to the DTO:

```bash
dox build_runner:build
```

If `dox serve` or `dox build_runner:watch` is running, this happens for you on every save.

## Defining fields

Each field is a `final` field and a parameter of the constructor. Put rules on a field as annotations:

```dart title="lib/app/dtos/create_user/create_user.dto.dart"
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

Keep the `part` line and the `static const DtoSchema<CreateUser> schema` line. They connect the class to its generated code.

The Dart type decides if a field is required. A field that is not nullable and has no default is required. A nullable field, or a field with a default, is optional. See [Required and optional fields](validation.md#required-and-optional-fields).

### Field types

These field types work:

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

If a client sends numbers as text in JSON too, use `@Dto(coerce: true)`. Then `"18"` is read as `18`, `"4.5"` as `4.5`, and `"true"`, `"1"`, `"yes"`, `"on"` (and the opposites) as a bool. A `bool` also takes the numbers `1` and `0`:

```dart
@Dto(coerce: true)
class UpdateStock {
  final int count; // {"count": "18"} gives 18
  final bool active; // {"active": 1} gives true

  const UpdateStock({required this.count, required this.active});
}
```

Every detail is in [Types in detail](validation-rules.md#types-in-detail).

### Nested objects and lists

Sometimes the input has an object inside it, or a list of objects. A field can be another `@Dto` class, or a list of them:

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

### Input keys

The input key is the field name in snake_case, so `firstName` reads `first_name`. Use `@Name` to pick another key:

```dart
final String firstName; // key: first_name

@Name('emailAddress')
final String email; // key: emailAddress
```

To use the field names as they are, use `@Dto(keyCase: KeyCase.field)`.

Unknown keys are dropped. If you want an unknown key to be an error, use `@Dto(strict: true)`.

## Registering DTOs

Dox uses no reflection, so it needs a list of all your DTOs. The generator writes this list to `lib/generated/dtos.g.dart`. Give it to the app config:

```dart title="lib/config/app.dart"
import 'package:my_app/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos, // from lib/generated/dtos.g.dart
  // ...
);
```

A new app already has this line. You only add it once, and new DTOs join the list when the generator runs. Without it, Dox throws an error that tells you to add it.

## Using a DTO in a controller

Add a parameter with the DTO type. Dox checks the request before your method runs:

```dart
@Inject()
class UserController {
  Future<User> store(CreateUser body) async {
    User user = User()
      ..name = body.name
      ..email = body.email;
    await user.save();
    return user;
  }
}
```

You can mix it with other parameters, like `DoxRequest` and path params. A method can have at most one DTO parameter:

```dart
Future<User> update(DoxRequest req, int id, UpdateUser body) async { ... }
```

See [Controller: parameters](controller.md#parameters) for the full rules.

### Validating inside the method

Sometimes you want to check the input later in the method, not before it. Use `req.validate<T>()`. It returns the object, or throws the `422` error:

```dart
CreateUser data = await req.validate<CreateUser>();
```

### Body and query string

Dox reads **one** source, and it never mixes the query and the body:

| Request | Dox reads |
| --- | --- |
| `GET`, `HEAD`, `DELETE` | the query string |
| `POST`, `PUT`, `PATCH` | the body (JSON, form or multipart) |

So a DTO for a list page, like `GET /users?page=2`, reads the query string for you. To choose the source yourself, set `source` on the DTO, or on one call:

```dart
@Dto(source: Source.query) // on the DTO
class SearchUsers { ... }

await req.validate<SearchUsers>(source: Source.query); // for one call
```

Path params are not part of a DTO. Ask for them as controller parameters, like `int id`. See the [Pagination](../guides/pagination.md) guide for a full query DTO.

### Uploaded files

A `RequestFile` field reads a file from a `multipart/form-data` request. Add [file rules](validation-rules.md#files) to check its type and size:

```dart
@Image()
@MaxSize('2MB')
final RequestFile avatar;

@Mimes(<String>['pdf', 'docx'])
final List<RequestFile> documents;
```

Dox checks the real file type from its first bytes. It does not trust the file name or the client. To save the file, see [Request: form data](request.md#form-data-file) and the [File upload](../guides/file-upload.md) guide.

## When validation fails

When the input is wrong, Dox answers `422` with one message per field, and your method does not run:

```json
{
  "email": "The email is not a valid email"
}
```

On a form post with a [session](session.md#validation-errors-and-old-input), Dox redirects back with the errors instead. To change the messages or add your own rules, see [Validation](validation.md).

## OpenAPI docs

If you use [`dox_openapi`](../packages/openapi.md), each DTO becomes a schema in the API docs. The field types and the rules (like `@Length` and `@Email`) show up there, so the docs always match the checks. A `///` comment or `@Describe('...')` on a field becomes its `description`. See [API docs with OpenAPI](../guides/api-docs-with-openapi.md#5-see-how-a-dto-becomes-a-schema).

## MCP tools

An [MCP](../packages/mcp.md) tool can use a DTO as its input. Extend `McpDtoTool<T>`, and `handle` gets the checked object, with the same rules as a controller. See [Tools that take a DTO](../packages/mcp.md#tools-that-take-a-dto).

## Sharing with Flutter

The generated DTO code is pure Dart, so a Flutter app can use the same DTO to check a form before it sends it. Put the DTO in a shared package and import `dox_validation` instead of `dox_core`. See [Share code with Flutter](../guides/share-code-with-flutter.md).

## Testing

A DTO is a normal Dart class. If you want to skip the checks in a test, for example to test a service, make one directly:

```dart
CreateUser input = const CreateUser(name: 'Ann', email: 'ann@dox.dev');
```

To test the checks, use `safeValidateMap` on the schema. It never throws:

```dart
ParseResult<CreateUser> result = await CreateUser.schema.safeValidateMap(<String, dynamic>{
  'name': 'A',
  'email': 'not-an-email',
});

expect(result.success, isFalse);
expect(result.errors['email'], 'The email is not a valid email');
```

`validateMap` does the same, but returns the object or throws. Pass `source: Source.query` to read the map like a query string, and `params: {'id': '5'}` to give path params. `@Unique` and `@Exists` need a test database.

## Details

- All `@Dto(...)` options are in [Keys and DTO options](validation-rules.md#keys-and-dto-options).
- The content type of the body decides how Dox reads it. See [Body types](validation-rules.md#body-types).
- The generator stops with a clear error for a field it can not use, like a field that is not `final`. See [What the generator checks](validation-rules.md#what-the-generator-checks).
- A trailing `Dto` in the `make:dto` name is removed: `dox make:dto CreateUserDto` gives the class `CreateUser`.

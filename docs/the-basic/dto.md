---
icon: lucide/package
---

# DTOs

A DTO is a typed Dart class that describes the input of a request, so your controller gets checked data instead of a raw map.

A **DTO** (data transfer object) is a class with `@Dto()`. Each field has a Dart type and some [rules](validation.md#rules). When the input is wrong, the client gets 422, and your method does not run.

## Creating a DTO

Make a DTO with the CLI. It writes `lib/app/dtos/<name>/<name>.dto.dart`:

```bash
dox make:dto CreateUser
```

Then run the generator. It writes a `.dto.g.dart` file next to the DTO. `dox serve` and `dox build_runner:watch` run it on every save:

```bash
dox build_runner:build
```

## Defining fields

Each field is a final field and a parameter of the constructor. Put rules on a field as annotations:

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

Keep the `part` line and the `schema` line. They connect the class to its generated code.

A field that is not nullable and has no default is required. See [Required and optional fields](validation.md#required-and-optional-fields).

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

JSON is strict: "18" is not an integer. See [Types in detail](validation-rules.md#types-in-detail).

### Numbers as text in JSON

Read numbers and bools that a client sends as text in JSON:

```dart
@Dto(coerce: true)
class UpdateStock {
  final int count; // {"count": "18"} gives 18
  final bool active; // {"active": 1} gives true

  const UpdateStock({required this.count, required this.active});
}
```

### Nested objects and lists

A field can be another `@Dto` class, or a list of them:

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

An error in a nested value has a path key, like `items.1.quantity`.

### Input keys

The input key is the field name in snake case, so `firstName` reads `first_name`. Use `@Name` to pick another key:

```dart
final String firstName; // key: first_name

@Name('emailAddress')
final String email; // key: emailAddress
```

`@Dto(keyCase: KeyCase.field)` uses the field names as they are. Unknown keys are dropped, and `@Dto(strict: true)` makes them an error. All options are in [Keys and DTO options](validation-rules.md#keys-and-dto-options).

## Registering DTOs

The generator writes the list of all DTOs to `lib/generated/dtos.g.dart`. Give it to the app config one time. A new app already has this line:

```dart title="lib/config/app.dart"
import 'package:my_app/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos,
);
```

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

A method can have one DTO parameter, next to others like `DoxRequest` and path params. See [Controller: parameters](controller.md#parameters).

### Validating inside the method

Check the input later in the method. It gives the object, or throws the 422 error:

```dart
CreateUser data = await req.validate<CreateUser>();
```

### Body and query string

Dox reads one source. It never mixes the query and the body:

| Request | Dox reads |
| --- | --- |
| GET, HEAD, DELETE | the query string |
| POST, PUT, PATCH | the body (JSON, form or multipart) |

Set `source` to pick the source, on the DTO or on one call:

```dart
@Dto(source: Source.query) // on the DTO
class SearchUsers { ... }

await req.validate<SearchUsers>(source: Source.query); // for one call
```

Path params are not part of a DTO. See the [Pagination](../guides/pagination.md) guide for a full query DTO.

### Uploaded files

A `RequestFile` field reads a file from a multipart request. Add [file rules](validation-rules.md#files) to check its type and size:

```dart
@Image()
@MaxSize('2MB')
final RequestFile avatar;

@Mimes(<String>['pdf', 'docx'])
final List<RequestFile> documents;
```

Dox checks the real file type from its first bytes. To save the file, see [Request: form data](request.md#form-data-file).

## When validation fails

Dox answers 422 with one message for each field:

```json
{
  "email": "The email is not a valid email"
}
```

On a form post with a [session](session.md#validation-errors-and-old-input), Dox redirects back with the errors. To change the messages, see [Validation](validation.md).

## Converting a DTO

Build a DTO from trusted data with no checks, or turn it into a map with the input keys:

```dart
CreateUser user = CreateUser.schema.fromMap(<String, dynamic>{
  'name': 'Ann',
  'email': 'ann@dox.dev',
});
Map<String, dynamic> map = CreateUser.schema.toMap(user);
```

Get the JSON Schema of the DTO:

```dart
Map<String, dynamic> json = CreateUser.schema.toJsonSchema();
```

## Returning a DTO

A DTO can also be the response. Return the object, or a list of them, from a controller. Dox writes the fields as JSON, with the same keys that the DTO reads:

```dart
@Dto()
class ProductView {
  final int id;
  final String productName;
  final DateTime? soldAt;

  const ProductView({required this.id, required this.productName, this.soldAt});
}
```

```dart
ProductView show(DoxRequest req) {
  return const ProductView(id: 1, productName: 'Book');
}
```

The client gets this JSON:

```json
{"id": 1, "product_name": "Book", "sold_at": null}
```

Dox makes the JSON with `toMap()` of the DTO. A DTO is for input. For fast JSON output, use [`@Serialize()`](serializer.md#fast-json-with-serialize).

These rules apply:

- The DTO must be in `AppConfig(dtos: dtos)`. See [Registering DTOs](#registering-dtos).
- A `DateTime` becomes ISO 8601 text. An enum becomes its name.
- A `Maybe` field with no value is not in the JSON.
- A DTO class with its own `toJson()` keeps it. The response is then the map of that method.

Run `dart run build_runner build` after you change a field.

## Using a DTO in other places

- [OpenAPI docs](../guides/api-docs-with-openapi.md#5-see-how-a-dto-becomes-a-schema): each DTO becomes a schema. A `///` comment or `@Describe('...')` on a field becomes its description.
- [MCP tools](../packages/mcp.md#tools-that-take-a-dto): extend `McpDtoTool<T>` to get the checked object.
- [Flutter](../guides/share-code-with-flutter.md): import `dox_validation` in a shared package, and check a form before you send it.

## Testing

Make a DTO directly to skip the checks:

```dart
CreateUser input = const CreateUser(name: 'Ann', email: 'ann@dox.dev');
```

Test the checks with `safeValidateMap`. It never throws:

```dart
ParseResult<CreateUser> result =
    await CreateUser.schema.safeValidateMap(<String, dynamic>{
  'name': 'A',
  'email': 'not-an-email',
});

expect(result.success, isFalse);
expect(result.errors['email'], 'The email is not a valid email');
```

`validateMap` gives the object or throws. Pass `source: Source.query` to read the map like a query string, and `params:` to give path params. `@Unique` and `@Exists` need a test database.

## Next steps

- [Validation](validation.md): rules, messages and custom checks.
- [Validation rules](validation-rules.md): every rule and option.
- [Request](request.md): raw input and files.

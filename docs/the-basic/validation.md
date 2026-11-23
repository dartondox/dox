---
icon: lucide/list-checks
---

# Validation

Validation checks the request input with a typed [DTO](dto.md) class, so your controller only gets good data.

Put rules on the fields of a DTO, then ask for it in your controller. When the input is wrong, Dox answers 422 with the errors:

```dart title="lib/app/dtos/create_user/create_user.dto.dart"
@Dto()
class CreateUser {
  @Trim()
  @Length(min: 3, max: 50)
  final String name;

  @Email()
  final String email;

  @MinLength(8)
  final String password;

  const CreateUser({
    required this.name,
    required this.email,
    required this.password,
  });

  static const DtoSchema<CreateUser> schema = $CreateUserDto;
}
```

```dart title="lib/app/http/controllers/user.controller.dart"
Future<User> store(CreateUser body) async {
  // body is already checked
  User user = User()
    ..name = body.name
    ..email = body.email
    ..password = await Hash.makeAsync(body.password);
  await user.save();
  return user;
}
```

To make and register a DTO, see [DTOs](dto.md).

## Required and optional fields

The Dart type decides if a field is required:

| Field | Key missing | Value null |
| --- | --- | --- |
| `final String name;` | error `required` | error `required` |
| `final int? age;` | null | null |
| `final Role role;` with `this.role = Role.user` | `Role.user` | error `required` |

Rules on an optional field run only when it has a value. The rules do not check a default value.

### Empty strings and spaces

An empty string counts as missing, so a required string rejects "". Add `@AllowEmpty()` to keep it:

```dart
@AllowEmpty()
final String note;
```

Spaces are kept, so "   " passes, unless the field has `@Trim()`. To trim all text fields, set it on the DTO:

```dart
@Dto(trim: true) // trim every text field
class CreatePost { ... }
```

`@Dto(emptyStringsToNull: true)` makes "" null.

### Using the default for bad values

Turn a bad value into the default, with no error. The field needs a default, a nullable type or a `Maybe` type:

```dart
@OrDefault()
@NotIn(<int>[0])
final int page; // with this.page = 1, page=abc and page=0 give 1
```

### Missing or null (for PATCH)

A `T?` field gives null for a missing key and for null. Use `Maybe<T>` to know the difference:

```dart
@Length(max: 500)
final Maybe<String?> bio; // default: const Maybe.missing()

// in the controller
if (body.bio.isPresent) {
  user.bio = body.bio.value; // can be null: the client cleared it
}
```

## Rules

Rules run from top to bottom, and the first rule that fails gives the error:

```dart
@Trim()
@Lowercase()
@Email()
@MaxLength(255)
final String email;
```

A rule on a list checks each item. Only the list rules check the list itself. Every rule, with its error code and message, is in [Validation rules](validation-rules.md):

| Kind | Annotations |
| --- | --- |
| Text | `@Length`, `@MinLength`, `@MaxLength`, `@Email`, `@Url`, `@Uuid`, `@Ulid`, `@Ip`, `@Regex`, `@In`, `@NotIn`, `@StartsWith`, `@EndsWith`, `@Alpha`, `@AlphaNumeric`, `@AlphaDash` |
| Change text | `@Trim`, `@Lowercase`, `@Uppercase`, `@AllowEmpty` |
| Numbers | `@Min`, `@Max`, `@Range`, `@Positive`, `@GreaterThan`, `@LessThan`, `@In`, `@NotIn` |
| Lists | `@MinItems`, `@MaxItems`, `@UniqueItems` |
| Dates | `@After`, `@Before`, `@AfterOrEqual`, `@BeforeOrEqual` |
| Other fields | `@Same`, `@Confirmed`, `@Different`, `@GreaterThanField`, `@GreaterThanOrEqualField`, `@LessThanField`, `@LessThanOrEqualField`, `@ProhibitedIf` |
| Present or missing | `@RequiredIf`, `@RequiredUnless`, `@RequiredWith`, `@RequiredWithout`, `@RequiredWithoutAll`, `@Filled`, `@Present`, `@Prohibited`, `@Accepted`, `@Declined` |
| Skip a field | `@ExcludeIf`, `@ExcludeUnless` |
| Files | `@MaxSize`, `@MinSize`, `@Mimes`, `@MimeTypes`, `@Image`, `@Dimensions` |
| Database | `@Unique`, `@Exists` |

## Checks across fields

Add a `validate` method to the DTO. Dox calls it after all field rules pass:

```dart
void validate(DtoErrors errors) {
  if (password != passwordConfirmation) {
    errors.add('password_confirmation', 'The passwords do not match');
  }
}
```

The key is the input key. Use `_root` for an error about the full body. `errors.has(key)` tells if a key already has an error. The method can be async.

## Database rules: `@Unique` and `@Exists`

Check the database, for example that an email is not taken. Import `package:dox_orm/dox_orm.dart` in the DTO file:

```dart
@Unique('users', column: 'email')
final String email;

@Exists('teams') // column defaults to id
final int teamId;
```

For an update, skip the row of the route param:

```dart
// PUT /users/{id}
@Unique('users', column: 'email', ignoreParam: 'id')
final String email;
```

These rules run last. See [Validation rules: database](validation-rules.md#database).

## The error response

Dox answers 422 with one message for each field. The key is the path to the value:

```json
{
  "email": "The email is not a valid email",
  "tags.0": "The tags may not be greater than 20 characters",
  "items.1.quantity": "The quantity must be greater than 0"
}
```

On a form post with a [session](session.md#validation-errors-and-old-input), Dox redirects back with the errors. The `laravelErrors` flag sends `{"message": "...", "errors": {"field": ["..."]}}`. See [Core flags](../reference/app-config.md#core-flags).

For another shape, read `error.issues` of the `ValidationException` in your [ExceptionHandler](errors.md). Each issue has `dottedPath`, `code`, `message` and `params`.

## Messages

Set your own error text. There are three places, and the first one wins.

On the rule:

```dart
@Email(message: 'Please check your email')
final String email;
```

On the DTO, by code or by `key.code`. Use `*` for list items, like `'tags.*.required'`:

```dart
@Dto(messages: <String, String>{
  'email.required': 'We need your email',
  'integer': 'The {field} must be a number',
})
```

For the full app, with a `MessageResolver`:

```dart
AppConfig appConfig = AppConfig(
  validationMessages: MessageResolver(
    messages: <String, String>{'required': 'Please fill in {field}'},
  ),
);
```

A message can use `{field}` (the last key), `{value}`, and rule values like `{min}` and `{max}`.

### Messages in other languages

Extend `MessageResolver` and override `resolve`. `request.locale` comes from Accept-Language:

```dart
class AppMessages extends MessageResolver {
  static const Map<String, Map<String, String>> _texts =
      <String, Map<String, String>>{
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
```

`setMessages` adds messages to a resolver at a later time.

### Names for `{field}`

Show a nice name in place of the key, on the DTO:

```dart
@Dto(attributes: <String, String>{'first_name': 'first name'})
class CreateUser { ... }
// The first name is required
```

Or for the full app, also for fluent schemas:

```dart
AppConfig appConfig = AppConfig(
  validationMessages: MessageResolver(
    attributes: <String, String>{'first_name': 'first name'},
  ),
);
```

The key in the error response stays the same. `setAttributes` adds names later, and a custom resolver can override `attributeName(path)`.

### Short rule names in message keys

With the `laravelMessageKeys` flag, a message key can use a short name. So `'name.min'` gives the message for the `min_length` error of `name`. Set it in the `setup()` of a provider, like the [other flags](../packages/validation.md#opt-in-flags):

```dart
Validator.flags = const ValidationFlags(laravelMessageKeys: true);
```

The full code wins over the short name. The error code in the response stays `min_length`:

| Dox code | Short name |
| --- | --- |
| `min_length` | `min` |
| `max_length` | `max` |
| `length` | `size` |
| `length_between` | `between` |
| `start_with` | `starts_with` |
| `end_with` | `ends_with` |
| `alpha_numeric` | `alpha_num` |
| `greater_than` | `gt` |
| `less_than` | `lt` |
| `min_items` | `min` |
| `max_items` | `max` |
| `unique_items` | `distinct` |
| `min_size` | `min` |
| `max_size` | `max` |
| `mime_types` | `mimetypes` |
| `datetime` | `date` |

## Custom rules

Extend `Rule<T>`. `T` is the field type, or the item type for a list:

```dart
class Slug extends Rule<String> {
  const Slug({super.message});

  @override
  String get name => 'slug'; // the error code

  @override
  String get defaultMessage => 'The {field} must be a slug';

  @override
  bool check(String value, RuleContext context) {
    return _pattern.hasMatch(value);
  }

  static final RegExp _pattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
}
```

Then use it like any rule:

```dart
@Slug()
final String slug;
```

- Override `params` to give values to the message, like `{'min': 3}`.
- Override `toJsonSchema` to add JSON Schema keys, like `{'format': 'slug'}`.
- `context.lookup('other.key')` reads another input value, and `context.sibling('key')` reads a field next to this one. Both give `undefined` for a missing value.
- `context.value`, `context.field` and `context.root` give the value, the field name and the full input.

### Rules that read the database

Extend `AsyncRule<T>` and write `checkAsync`:

```dart
class FreeName extends AsyncRule<String> {
  const FreeName({super.message});

  @override
  String get name => 'free_name';

  @override
  String get defaultMessage => 'The {field} is taken';

  @override
  Future<bool> checkAsync(String value, RuleContext context) async {
    return await nameIsFree(value); // your database check
  }
}
```

For a list field, override `failedItems` to check all items in one query. It gives the indexes of the bad items.

## Dynamic input

For input you know only at runtime, like form fields from the database, use a fluent schema:

```dart
Map<String, dynamic> data = await req.validateSchema(v.object(fields));
```

See [Fluent schemas](../packages/validation.md#fluent-schemas-for-dynamic-input).

## Testing

Test the checks of a DTO with `safeValidateMap`. See [DTOs: testing](dto.md#testing).

## Next steps

- [DTOs](dto.md): the typed class that holds the input.
- [Validation rules](validation-rules.md): every rule.
- [Validation package](../packages/validation.md): opt-in flags, fluent schemas and use without Dox.

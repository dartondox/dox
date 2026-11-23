---
icon: lucide/list-checks
---

# Validation

Validation checks the request input with a typed [DTO](dto.md) class, so your controller only gets good data.

You write a class with `@Dto()` and put rules on its fields. Then you ask for it in your controller. Dox reads the request, checks it, and gives you a typed object. When the input is wrong, Dox answers `422` with the errors, and your controller does not run.

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

  @MinLength(8)
  final String password;

  @Min(18)
  final int? age; // nullable, so optional

  const CreateUser({
    required this.name,
    required this.email,
    required this.password,
    this.age,
  });

  static const DtoSchema<CreateUser> schema = $CreateUserDto;
}
```

```dart title="lib/app/http/controllers/user.controller.dart"
class UserController {
  Future<User> store(CreateUser body) async {
    // body is already checked
    User user = User()
      ..name = body.name
      ..email = body.email
      ..password = await Hash.makeAsync(body.password);
    await user.save();
    return user;
  }
}
```

To create a DTO, register it with the app, and use it for the body, the query string or files, see [DTOs](dto.md). This page is about the rules and the error messages.

## Required and optional fields

The Dart type decides if a field is required, so you do not write `required` or `nullable`:

| Field | Key missing | Value `null` |
| --- | --- | --- |
| `final String name;` | error `required` | error `required` |
| `final int? age;` | `null` | `null` |
| `final Role role;` with `this.role = Role.user` | `Role.user` | error `required` |

Rules on an optional field run only when it has a value. A default value is used only when the key is missing, and the rules do not check it.

### Empty strings and spaces

**An empty string counts as missing.** So a required `String` rejects `""`. Add `@AllowEmpty()` to keep `""`.

**Spaces are kept.** So `"   "` passes `required`, unless the field has `@Trim()`. To trim every text field of a DTO, use `@Dto(trim: true)`. Then `"   "` counts as missing.

If you want `""` to be `null` instead, use `@Dto(emptyStringsToNull: true)`.

### Using the default for bad values

Sometimes a bad value should not be an error. For example, `page=abc` in a list page should just give page 1. `@OrDefault()` turns a bad value into the default, with no error:

```dart
@OrDefault()
@NotIn(<int>[0])
final int page; // with this.page = 1, page=abc and page=0 give 1
```

The field needs a default, a nullable type or a `Maybe` type.

### Missing or `null`? (for PATCH)

In a PATCH request, a missing key means "do not change it", and `null` means "clear it". A `T?` field gives `null` for both. To know the difference, use `Maybe<T>`:

```dart
@Length(max: 500)
final Maybe<String?> bio; // default: const Maybe.missing()

// in the controller
if (body.bio.isPresent) {
  user.bio = body.bio.value; // can be null: the client cleared it
}
```

## Rules

Put rules on a field as annotations. They run from top to bottom, and the first rule that fails gives the error:

```dart
@Trim()
@Lowercase()
@Email()
@MaxLength(255)
final String email;
```

A rule on a list checks each item, like `@Email()` on a `List<String>`. Only the list rules check the list itself. For a few allowed values, use a Dart `enum`, or `@In(<String>['draft', 'published'])`.

These are the rules. Every rule, with its error code and message, is in [Validation rules](validation-rules.md):

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

## Checks across fields: `validate()`

Some checks need more than one field. Add a `validate(DtoErrors errors)` method to the DTO. Dox calls it after all field rules passed:

```dart
void validate(DtoErrors errors) {
  if (password != passwordConfirmation) {
    errors.add('password_confirmation', 'The passwords do not match');
  }
}
```

The key is the input key (snake_case). Use `_root` for an error about the whole body. `errors.has(key)` tells you if a key already has an error.

The method can be `async`. Do not throw for bad input. Add an error.

## Database rules: `@Unique` and `@Exists`

Sometimes you need to check the database, for example that an email is not taken yet. `@Unique` and `@Exists` do this. They come from `dox_orm`, so add `import 'package:dox_orm/dox_orm.dart';` to the DTO file:

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

These rules read the database, so they run last. All options are in [Validation rules: database](validation-rules.md#database). The full order of checks is in [The order of checks](validation-rules.md#the-order-of-checks).

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

On a form post with a [session](session.md#validation-errors-and-old-input), Dox redirects back with the errors instead.

If you need another error shape, read `error.issues` of the `ValidationException` in your `ExceptionHandler`. Each issue has its `dottedPath`, its rule `code` (like `min_length`), its `message` and its `params`.

## Messages

Sometimes you want your own error text. You can change a message in three places. The first one wins.

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

For the whole app, with a `MessageResolver`. Use it for other languages:

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

A message can use placeholders: `{field}` (the last key), `{value}`, and rule values like `{min}` and `{max}`.

### Names for `{field}`

By default `{field}` is the key, like `The first_name is required`. To show a nicer name, give attribute names on the DTO:

```dart
@Dto(attributes: <String, String>{'first_name': 'first name'})
class CreateUser { ... }
// The first name is required
```

Or for the whole app (and for fluent schemas), in the `MessageResolver`:

```dart
AppConfig appConfig = AppConfig(
  validationMessages: MessageResolver(
    attributes: <String, String>{'first_name': 'first name'},
  ),
  // ...
);
```

A key with no name still shows the key. Only the text changes. The key in the error response stays the same.

### Short rule names in message keys

Some error codes are long, like `min_length`. With the opt-in flag `laravelMessageKeys`, a message key can also use a short name. So `'name.min'` gives the message for the `min_length` error of `name`. Without the flag, only the full codes match. Set the flag in a provider's `setup()`, like the [other flags](../packages/validation.md#opt-in-flags):

```dart
Validator.flags = const ValidationFlags(laravelMessageKeys: true);
```

The error code in the response does not change: it is still `min_length`. These are the short names:

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

If no built-in rule fits, write your own. Extend `Rule<T>`. `T` is the field type (or the item type, for a list):

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
```

Then use it like any rule:

```dart
@Slug()
final String slug;
```

- If the rule has values, add `final` fields and override `params`. They become placeholders.
- `context.lookup('other.key')` reads another input value.
- `context.sibling('key')` reads the raw input of a field next to this one, in the same object. For example, `context.sibling('password_confirmation')` in a rule on `password`. It gives `undefined` when the field is missing.
- If the rule needs the database, extend `AsyncRule<T>` and write `checkAsync`.

## Dynamic input

Sometimes the shape of the input is known only at runtime, like form fields from the database. Use a fluent schema for this:

```dart
Map<String, dynamic> data = await req.validateSchema(v.object(fields));
```

See [Fluent schemas](../packages/validation.md#fluent-schemas-for-dynamic-input). Use a DTO for everything else.

## Testing

To test the checks of a DTO, use `safeValidateMap` on its schema. See [DTOs: testing](dto.md#testing).

## Details

This section is for special cases. Most apps do not need it.

### Flags

- The flag `laravelErrors` sends `{"message": "...", "errors": {"field": ["..."]}}` as the error response. See [Core flags](../reference/app-config.md#core-flags).
- Three [opt-in flags](../packages/validation.md#opt-in-flags) change how DTOs are checked: get all errors at once, reject `[]` in a required list, and reject `""` in a `Maybe` field.

### Empty values and defaults

- `@Dto(trim: true)` works like `@Trim()` on each `String` field and on the text items of its lists and maps. A nested DTO uses its own `@Dto(trim:)`. The same is true for `@Dto(coerce:)`.
- With `@Dto(emptyStringsToNull: true)` and `@Dto(trim: true)`, blank text like `"  "` is `null` as well. Then `{"bio": ""}` clears a `Maybe<String?>` field. A required field still gets `required`. A field that is not nullable but has a default gets `required` too, because `null` is not a missing key.
- `@OrDefault()` works on any field, in a body or a query. A `Maybe` field gets `Maybe.missing()`. Errors from async rules (`@Unique`, `@Exists`, your `AsyncRule`) and from `validate()` are not dropped. They run later, on the built object, and still give `422`.

### Messages

- In `@Dto(messages:)`, a full dotted path works too, like `'address.city.required'`. It also reaches a nested DTO. A message in the nested DTO itself, like `'city.required'`, wins over it.
- A name for `{field}` is looked up by the dotted path (`address.city`), then with `*` for list items (`items.*.qty`), then by the field name (`city`).
- The names of the DTO win over the names of the `MessageResolver`. A nested DTO uses its own names first, then the names of the outer DTO.
- `MessageResolver.setAttributes(...)` adds names to a resolver. A custom resolver can override `attributeName(path)`.
- `{other}` and `{others}` (the other keys of rules like `@RequiredIf` and `@Same`) show their names too.
- `@Dto(attributes:)` needs one `build_runner` run.
- With `laravelMessageKeys`, the full code is tried first at each step of the lookup, then the short name. So `'name.min_length'` wins over `'name.min'`. A key with a path still wins over a key with only a code: `'name.min'` wins over `'min_length'`.
- Short names work in `@Dto(messages:)` and in a `MessageResolver`. A code that is already short (like `email` or `required`) needs nothing. With the flag on, a key `min` or `max` with no path fits text, list and file errors too, not only numbers.

## See also

- [DTOs](dto.md): the typed class that holds the input.
- [Validation rules](validation-rules.md): every rule.
- [Validation](../packages/validation.md): fluent schemas and use without Dox.

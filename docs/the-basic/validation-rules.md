# Validation rules

This page lists every annotation you can put on a `@Dto` field. See [Validation](validation.md) for how DTOs work.

How to read the tables:

- **Code** is the error code. Use it in `@Dto(messages: ...)` and in a `MessageResolver`.
- **Message** is the default English text. `{field}` is the last key of the path.
- Every annotation also takes `message:`. It wins over every other message.
- All limits include the limit itself, unless the table says "exclusive".
- On a `List<T>` field, a value rule checks each item. Only the list rules check the list itself.

## Type errors

These have no annotation. They come from the field type.

| Code | When | Message |
| --- | --- | --- |
| `required` | a required field is missing, `null`, or `""` | `The {field} is required` |
| `string` | not a string | `The {field} must be a string` |
| `integer` | not a whole number | `The {field} must be an integer` |
| `numeric` | not a number (`double`, `num`) | `The {field} must be a number` |
| `boolean` | not a bool | `The {field} must be a boolean` |
| `date` | not an ISO 8601 date | `The {field} must be a date` |
| `in` | not a name of the enum | `The selected {field} is invalid. Valid options are {values}` |
| `array` | not a list | `The {field} must be an array` |
| `object` | not an object (nested DTO, `Map`) | `The {field} must be an object` |
| `file` | not a file | `The {field} must be a file` |
| `unrecognized_keys` | unknown key, with `@Dto(strict: true)` | `The {field} field is not allowed` |

## Text

For `String` fields (and `List<String>` items).

| Annotation | Code | Message | JSON Schema |
| --- | --- | --- | --- |
| `@Length(min: 3, max: 50)` | `length_between` | `The {field} must be between {min} and {max} characters` | `minLength`, `maxLength` |
| `@Length(min: 6, max: 6)` | `length` | `The {field} must be exactly {length} characters` | `minLength`, `maxLength` |
| `@MinLength(3)` | `min_length` | `The {field} must be at least {min} characters` | `minLength` |
| `@MaxLength(50)` | `max_length` | `The {field} may not be greater than {max} characters` | `maxLength` |
| `@Email()` | `email` | `The {field} is not a valid email` | `format: email` |
| `@Url()` | `url` | `The {field} must be a url` | `format: uri` |
| `@Uuid()` | `uuid` | `The {field} is invalid uuid` | `format: uuid` |
| `@Ip()` | `ip` | `The {field} must be an ip address` | `anyOf` `ipv4` / `ipv6` |
| `@Regex(r'[a-z]+')` | `regex` | `The {field} format is invalid` | `pattern` |
| `@In(['a', 'b'])` | `in` | `The selected {field} is invalid. Valid options are {values}` | `enum` |
| `@NotIn(['root'])` | `not_in` | `The {field} field cannot be {value}` | `not: {enum}` |
| `@StartsWith('dox')` | `start_with` | `The {field} must start with {prefix}` | `pattern` |
| `@EndsWith('.dev')` | `end_with` | `The {field} must end with {suffix}` | `pattern` |
| `@Alpha()` | `alpha` | `The {field} must be an alphabetic` | `pattern` |
| `@AlphaNumeric()` | `alpha_numeric` | `The {field} must be only alphabetic and number` | `pattern` |
| `@AlphaDash()` | `alpha_dash` | `The {field} must be only alphabetic and dash` | `pattern` |

Details:

- `@Length` has `min:` and `max:`. Both are optional, but you must give one.
  With only `min:` it acts like `@MinLength`, with only `max:` like `@MaxLength`.
- Length counts characters (Unicode code points). `é` counts as 1.
- `@Url()` needs `http` or `https` and a host.
- `@Uuid()` takes any version. Upper or lower case.
- `@Regex(pattern, {message})` must match the **whole** value. You do not need `^` and `$`.
  The regex is checked when the generator runs. A bad regex stops the build.
- `@Alpha()`, `@AlphaNumeric()` and `@AlphaDash()` use ASCII letters `a-z`, `A-Z`. `@AlphaDash()` also allows `-` and `_`.
- `@In` and `@NotIn` compare exactly (case matters).

## Change text

These change the value before the rules run. They always run in this order, wherever you put them:
`@Trim`, then `@Lowercase` or `@Uppercase`, then the "empty string is missing" check.

| Annotation | Does |
| --- | --- |
| `@Trim()` | removes spaces at the start and the end |
| `@Lowercase()` | makes the text lower case |
| `@Uppercase()` | makes the text upper case |
| `@AllowEmpty()` | keeps `""` as a value. Without it, `""` counts as missing. |

They have no error and no JSON Schema output. `@Lowercase()` and `@Uppercase()` together stop the build.

## Numbers

For `int`, `double` and `num` fields (and list items).

| Annotation | Code | Message | JSON Schema |
| --- | --- | --- | --- |
| `@Min(18)` | `min` | `The {field} must be greater than or equal {min}` | `minimum` |
| `@Max(100)` | `max` | `The {field} must be less than or equal {max}` | `maximum` |
| `@Range(1, 10)` | `between` | `The {field} must be between {min} and {max}` | `minimum`, `maximum` |
| `@Positive()` | `greater_than` | `The {field} must be greater than 0` | `exclusiveMinimum: 0` |
| `@GreaterThan(0.5)` | `greater_than` | `The {field} must be greater than {min}` (exclusive) | `exclusiveMinimum` |
| `@LessThan(100)` | `less_than` | `The {field} must be less than {max}` (exclusive) | `exclusiveMaximum` |
| `@In([1, 2, 3])` | `in` | `The selected {field} is invalid. Valid options are {values}` | `enum` |
| `@NotIn([0])` | `not_in` | `The {field} field cannot be {value}` | `not: {enum}` |

The values are `num`. `@Min(1.5)` on an `int` field stops the build.

## Lists

For `List<T>` fields. These check the list, not the items.

| Annotation | Code | Message | JSON Schema |
| --- | --- | --- | --- |
| `@MinItems(1)` | `min_items` | `The {field} must have at least {min} items` | `minItems` |
| `@MaxItems(5)` | `max_items` | `The {field} may not have more than {max} items` | `maxItems` |
| `@UniqueItems()` | `unique_items` | `The {field} must not have duplicate items` | `uniqueItems: true` |

`@UniqueItems()` works for `String`, numbers, `bool`, enums and `DateTime`. On a list of DTOs it stops the build.

## Dates

For `DateTime` fields.

| Annotation | Code | Message | JSON Schema |
| --- | --- | --- | --- |
| `@After('2000-01-01')` | `after` | `The {field} must be a date after {date}` | `format: date-time` |
| `@Before('now')` | `before` | `The {field} must be a date before {date}` | `format: date-time` |

- The value is an ISO 8601 date, or `'now'` (the time of the request).
- Both are exclusive: `@After('2000-01-01')` does not accept `2000-01-01T00:00:00Z`.
- To compare two fields (end after start), use [`validate()`](validation.md#checks-across-fields-validate).

## Files

For `RequestFile` and `List<RequestFile>` fields.

| Annotation | Code | Message | JSON Schema |
| --- | --- | --- | --- |
| `@MaxSize('2MB')` | `max_size` | `The {field} may not be larger than {max}` | `maxLength` (bytes) |
| `@Mimes(['pdf', 'png'])` | `mimes` | `The {field} must be a file of type: {types}` | `contentMediaType` |
| `@Image()` | `image` | `The {field} must be an image` | `contentMediaType: image/*` |

- `@MaxSize` units: `B`, `KB`, `MB`, `GB`. `1KB` = 1024 bytes. A bad size text stops the build.
- `@Mimes` takes file extensions. Dox finds the real type from the first bytes of the file.
  The file name extension must fit those bytes too. So `x.html` with GIF bytes does not pass.
  For types without a byte signature (like `txt` or `csv`), it uses the file name extension.
- `@Image()` is `@Mimes(['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'])`. No `svg`.
- The JSON Schema of a file is `{"type": "string", "format": "binary"}`, plus the keys above.

## Database

From `dox_orm`. Async: they run after all other checks passed.

| Annotation | Code | Message |
| --- | --- | --- |
| `@Unique(table, {column, ignoreParam, ignoreColumn, connection})` | `unique` | `The {field} has already been taken` |
| `@Exists(table, {column, connection})` | `exists` | `The selected {field} is invalid` |

- `@Unique` column default: the input key. `@Exists` column default: `id`.
- `ignoreParam: 'id'` skips the row where `ignoreColumn` (default `id`) equals the path param `{id}`.
- They add nothing to the JSON Schema.

See [Database rules](validation.md#database-rules-unique-and-exists).

## Keys and DTO options

| Annotation | Does |
| --- | --- |
| `@Name('emailAddress')` | the input key for this field. Default: the field name in snake_case. |
| `@Dto()` | marks the class. |
| `@Dto(source: Source.query)` | where to read: `Source.auto` (default), `Source.query`, `Source.body`. |
| `@Dto(keyCase: KeyCase.field)` | keys: `KeyCase.snake` (default) or `KeyCase.field` (the Dart name as is). |
| `@Dto(strict: true)` | unknown keys are errors. Default `false`: they are dropped. |
| `@Dto(messages: {...})` | messages by `code` or `key.code`. |

A `///` doc comment on a field becomes its `description` in the JSON Schema.

## What the generator checks

The build stops with a clear error when:

- a field is not `final`, or is not a parameter of the unnamed constructor,
- a field type is not supported (see [Types](validation.md#types)),
- a rule does not fit the field type (like `@Email()` on an `int`),
- a `Maybe<T>` field has no `const Maybe.missing()` default,
- two `@Dto` classes in the app have the same name,
- the class is generic, or extends another class (other than `Object`).

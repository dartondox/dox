---
icon: lucide/ruler
---

# Validation rules

This page lists every annotation you can put on a `@Dto` field, with its error code and default message.

To learn how DTOs work, read [Validation](validation.md) first. How to read the tables:

- Code is the error code. Use it in `@Dto(messages: ...)` and in a `MessageResolver`.
- Message is the default English text. `{field}` is the last key of the path.
- Every annotation also takes `message:`. It wins over every other message.
- All limits include the limit itself, unless the table says "exclusive".
- On a list field, a value rule checks each item. Only the list rules check the list itself.

## Type errors

You get these errors when a value does not fit the field type. They have no annotation.

| Code | When | Message |
| --- | --- | --- |
| `required` | a required field is missing, null, or "" | `The {field} is required` |
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

Use these rules on string fields and string list items:

| Annotation | Code | Message | JSON Schema |
| --- | --- | --- | --- |
| `@Length(min: 3, max: 50)` | `length_between` | `The {field} must be between {min} and {max} characters` | `minLength`, `maxLength` |
| `@Length(min: 6, max: 6)` | `length` | `The {field} must be exactly {length} characters` | `minLength`, `maxLength` |
| `@MinLength(3)` | `min_length` | `The {field} must be at least {min} characters` | `minLength` |
| `@MaxLength(50)` | `max_length` | `The {field} may not be greater than {max} characters` | `maxLength` |
| `@Email()` | `email` | `The {field} is not a valid email` | `format: email` |
| `@Url()` | `url` | `The {field} must be a url` | `format: uri` |
| `@Uuid()` | `uuid` | `The {field} is invalid uuid` | `format: uuid` |
| `@Ulid()` | `ulid` | `The {field} must be a valid ULID` | `pattern` |
| `@Ip()` | `ip` | `The {field} must be an ip address` | `anyOf` `ipv4` / `ipv6` |
| `@Regex(r'[a-z]+')` | `regex` | `The {field} format is invalid` | `pattern` |
| `@In(['a', 'b'])` | `in` | `The selected {field} is invalid. Valid options are {values}` | `enum` |
| `@NotIn(['root'])` | `not_in` | `The {field} field cannot be {value}` | `not: {enum}` |
| `@StartsWith('dox')` | `start_with` | `The {field} must start with {prefix}` | `pattern` |
| `@EndsWith('.dev')` | `end_with` | `The {field} must end with {suffix}` | `pattern` |
| `@Alpha()` | `alpha` | `The {field} must be an alphabetic` | `pattern` |
| `@AlphaNumeric()` | `alpha_numeric` | `The {field} must be only alphabetic and number` | `pattern` |
| `@AlphaDash()` | `alpha_dash` | `The {field} must be only alphabetic, number, dash and underscore` | `pattern` |

- `@Length` needs `min:`, `max:` or both. With one of them, it acts like `@MinLength` or `@MaxLength`.
- Length counts characters (Unicode code points), so é counts as 1.
- `@Url()` needs http or https and a host.
- `@Uuid()` takes any version, in upper or lower case.
- `@Ulid()` takes 26 Crockford base32 characters, in upper or lower case. The first one is 0 to 7.
- `@Regex` must match the full value, so you do not need `^` and `$`. A bad regex stops the build.
- The alpha rules use the ASCII letters a-z and A-Z. `@AlphaDash()` also allows the digits 0-9, `-` and `_`.
- `@In` and `@NotIn` compare exactly, and case matters.

## More text rules

These are also for string fields:

| Annotation | Code | Message | JSON Schema |
| --- | --- | --- | --- |
| `@Json()` | `json` | `The {field} is not a valid json` | `contentMediaType: application/json` |
| `@Digits(6)` | `digits` | `The {field} must be {digits} digits` | `pattern` |
| `@DigitsBetween(4, 6)` | `digits_between` | `The {field} must be between {min} and {max} digits` | `pattern` |
| `@DateFormatted('Y-m-d')` | `date_format` | `The {field} must match the format {format}` | |
| `@HexColor()`, `@HexColor(short: true)` | `hex_color` | `The {field} must be a hex color like #1a2b3c` | `pattern` |
| `@Password(min: 8, ...)` | `password` | `The {field} must have {rules}` | `minLength` |

- `@HexColor()` takes # and 6 hex digits, in any case. With `short: true` it also takes 3 digits, like #abc.
- `@Digits` and `@DigitsBetween` take only 0-9, with no sign and no dot. Use a string field, so leading zeros stay.
- `@DateFormatted` uses these letters:
  day `d`, `j`, `D` (Mon), `l` (Monday), `N`, `w`, `S` (st), `z`;
  month `m`, `n`, `M` (Jan), `F` (January), `t`;
  year `Y`, `y`, `L`;
  time `a`, `A`, `g`, `h`, `G`, `H`, `i`, `s`, `v`, `u`;
  time zone `e`, `T`, `P`, `p`, `O`, `Z`, `I`;
  full `U`, `c`, `r`.
  Put `\` before a letter to use it as text, like `Y-m-d\TH:i`. Any other letter stops the build. Other characters must be there as they are.
  `j`, `n`, `g`, `G`, `z` and `U` take no leading zero, so `j/n/Y` rejects 01/02/2024.
  The date must exist, so 2023-02-29 fails. Names need the case shown (Jan, not jan), and a day name must fit the date. The field stays a string. Use a `DateTime` field for ISO 8601 dates.
- `@Password` options: `min` (default 8), `letters`, `mixedCase` (one upper and one lower case letter), `numbers` and `symbols`. The others are off by default. Letters, numbers and symbols are Unicode. `{rules}` lists the options you set, like "at least 8 characters and one number".

## Other fields

These rules read another key of the same object, like a password and its confirmation. Give the input key, like `account_type`, not the Dart name. A Dart name stops the build.

| Annotation | Code | Message |
| --- | --- | --- |
| `@Confirmed()` | `confirmed` | `The {field} confirmation does not match` |
| `@Same('email')` | `same` | `The {field} must match {other}` |
| `@RequiredIf('type', 'company')` | `required_if` | `The {field} is required when {other} is {values}` |
| `@RequiredWith(['phone'])` | `required_with` | `The {field} is required when {others} is present` |
| `@RequiredUnless('type', 'guest')` | `required_unless` | `The {field} is required unless {other} is {values}` |
| `@RequiredWithout(['email'])` | `required_without` | `The {field} is required when {others} is not present` |
| `@RequiredWithoutAll(['email', 'phone'])` | `required_without_all` | `The {field} is required when none of {others} are present` |
| `@Different('old_password')` | `different` | `The {field} and {other} must be different` |
| `@ProhibitedIf('type', 'guest')` | `prohibited_if` | `The {field} is prohibited when {other} is {values}` |
| `@GreaterThanField('min_price')` | `greater_than` | `The {field} must be greater than {min}` |
| `@GreaterThanOrEqualField('min_price')` | `min` | `The {field} must be greater than or equal {min}` |
| `@LessThanField('max_price')` | `less_than` | `The {field} must be less than {max}` |
| `@LessThanOrEqualField('max_price')` | `max` | `The {field} must be less than or equal {max}` |

- `@Confirmed()` on `password` needs the key `password_confirmation` with the same value. The error is on `password`. Use `@Confirmed(other: 'password_again')` for another key. The DTO needs no field for the confirmation key.
- `@Confirmed`, `@Same` and `@Different` compare the raw input of both keys, so `@Trim` does not change the compare. A missing other key passes `@Different`.
- Text and numbers match by text, so 1234 matches "1234".
- The required rules work on a nullable field, a `Maybe` field or a field with a default. On an always-required field the build stops.
- `@RequiredIf` and `@RequiredUnless` also take a list of values, like `@RequiredIf('type', ['company', 'shop'])`. An enum value matches its name: `@RequiredIf('role', Role.admin)` matches "admin".
- `@RequiredWith`: the field is required when any of the keys has a value. `@RequiredWithout`: when any of the keys is missing. `@RequiredWithoutAll`: when all of them are missing.
- `@RequiredUnless`: a missing other key counts as null, so the field is required then.
- `@ProhibitedIf`: when the other key matches, the field must be missing or empty. 0 and false fail.
- The field compare rules (`@GreaterThanField` and the others) are for number fields. A missing other key, or one that is not a number, fails. `{min}` and `{max}` in the message are the other key.
- On a list field, `@Different` checks the full list. The field compare rules do not fit a list.
- Missing means: not there, null, blank text, an empty list or an empty map.

## Present or missing

These rules check if a key is sent and has a value:

| Annotation | Code | Message |
| --- | --- | --- |
| `@Filled()` | `filled` | `The {field} must have a value` |
| `@Present()` | `present` | `The {field} must be present` |
| `@Prohibited()` | `prohibited` | `The {field} is prohibited` |
| `@Accepted()` | `accepted` | `The {field} must be accepted` |
| `@Declined()` | `declined` | `The {field} must be declined` |

- `@Filled()`: a missing key passes. A sent key must have a value: not null, not blank text, not an empty list.
- `@Present()`: the key must be sent. Its value can be null or empty.
- `@Prohibited()`: the key must be missing, or blank text. Any other value fails, also null, `[]`, `{}`, 0 and false.
- `@Filled`, `@Present` and `@Prohibited` are for a nullable, `Maybe` or default field.
- `@Accepted()` takes true, 1, "1", "true", "yes" and "on". `@Declined()` takes false, 0, "0", "false", "no" and "off". The text is case sensitive. Use them on a bool field with no default. In a JSON body a bool field takes only true and false, unless the DTO has `@Dto(coerce: true)`.

```dart
@Accepted()
final bool terms;

@Present()
final String? note; // the key must be there, null is fine
```

## Skip a field

These rules skip a field for some input, like a VAT number that is only for a company:

| Annotation | Does |
| --- | --- |
| `@ExcludeIf('type', 'person')` | when `type` is person, the field is skipped |
| `@ExcludeUnless('type', 'company')` | unless `type` is company, the field is skipped |

- A skipped field gets its default, null or `Maybe.missing()`, as if it was not sent.
- They match like `@RequiredIf`, also with a list of values.
- `@ExcludeIf`: a missing other key does not skip. `@ExcludeUnless`: a missing other key counts as null, so the field is skipped.
- They are for a nullable, `Maybe` or default field.
- Fluent schemas have `.excludeIf()` and `.excludeUnless()`. See [Skip a field](../packages/validation.md#skip-a-field).

```dart
final String type;

@ExcludeIf('type', 'person')
@MinLength(5)
final String? vatNumber; // not checked for a person
```

## Change text

These change the value before the rules run. They always run in this order: `@Trim`, then `@Lowercase` or `@Uppercase`, then the "empty string is missing" check.

| Annotation | Does |
| --- | --- |
| `@Trim()` | removes spaces at the start and the end |
| `@Lowercase()` | makes the text lower case |
| `@Uppercase()` | makes the text upper case |
| `@AllowEmpty()` | keeps "" as a value. Without it, "" counts as missing. |

`@Lowercase()` and `@Uppercase()` together stop the build.

## Bad value to default

| Annotation | Does |
| --- | --- |
| `@OrDefault()` | a bad value gives the default of the field (or null, or `Maybe.missing()`), not an error. |

- It drops type errors and the errors of the normal rules of the field.
- Errors from async rules and from `validate()` still give 422.
- The field needs a default, a nullable type or a `Maybe` type.

## Numbers

Use these rules on `int`, `double` and `num` fields and list items:

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

`@Min(1.5)` on an `int` field stops the build.

## Lists

Use these rules on list fields. They check the list, not the items:

| Annotation | Code | Message | JSON Schema |
| --- | --- | --- | --- |
| `@MinItems(1)` | `min_items` | `The {field} must have at least {min} items` | `minItems` |
| `@MaxItems(5)` | `max_items` | `The {field} may not have more than {max} items` | `maxItems` |
| `@UniqueItems()` | `unique_items` | `The {field} must not have duplicate items` | `uniqueItems: true` |

`@UniqueItems()` works for strings, numbers, bools, enums and dates. On a list of DTOs it stops the build.

## Dates

Use these rules on `DateTime` fields:

| Annotation | Code | Message | JSON Schema |
| --- | --- | --- | --- |
| `@After('2000-01-01')` | `after` | `The {field} must be a date after {date}` | `format: date-time` |
| `@Before('now')` | `before` | `The {field} must be a date before {date}` | `format: date-time` |
| `@AfterOrEqual('today')` | `after_or_equal` | `The {field} must be a date after or equal to {date}` | `format: date-time` |
| `@BeforeOrEqual('end_date')` | `before_or_equal` | `The {field} must be a date before or equal to {date}` | `format: date-time` |

- The value is one of these:
    - an ISO 8601 date, like '2000-01-01',
    - a word: 'now' (the time of the request), 'today', 'tomorrow' or 'yesterday'. These are in UTC, and 'today' is the start of the day,
    - the input key of another date field of the same DTO, like 'start_date'. When that field has no value, the check passes.
- `@After` and `@Before` are exclusive. `@AfterOrEqual` and `@BeforeOrEqual` accept the same time.

```dart
final DateTime startDate;

@After('start_date')
@BeforeOrEqual('tomorrow')
final DateTime endDate;
```

## Files

Use these rules on `RequestFile` and `List<RequestFile>` fields:

| Annotation | Code | Message | JSON Schema |
| --- | --- | --- | --- |
| `@MaxSize('2MB')` | `max_size` | `The {field} may not be larger than {max}` | `maxLength` (bytes) |
| `@Mimes(['pdf', 'png'])` | `mimes` | `The {field} must be a file of type: {types}` | `contentMediaType` |
| `@Image()` | `image` | `The {field} must be an image` | `contentMediaType: image/*` |
| `@MinSize('10KB')` | `min_size` | `The {field} must be at least {min}` | `minLength` (bytes) |
| `@MimeTypes(['image/png', 'image/*'])` | `mime_types` | `The {field} must be a file of type: {types}` | `contentMediaType` |
| `@Dimensions(minWidth: 100, ratio: 3 / 2)` | `dimensions` | `The {field} has invalid image dimensions` | `contentMediaType: image/*` |

- Size units are B, KB, MB and GB. 1KB is 1024 bytes.
- `@Mimes` takes file extensions. Dox finds the real type from the first bytes of the file. The file name extension must not name another type, or a type a browser runs (like html or svg). For zip types (like docx), the extension must match too. For types with no byte signature (like txt or csv), Dox uses the extension.
- `@Image()` is `@Mimes(['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'])`, with no svg.
- `@MimeTypes` takes MIME types and checks the real bytes like `@Mimes`. `image/*` means jpg, jpeg, png, gif, webp, bmp, tif, tiff, ico, heic, heif, avif and psd. Browsers can not show most of these, so for web images use `@Image()`. Write `image/jpeg`: `image/jpg` never matches.
- `@Dimensions` limits: `width`, `height` (exact), `minWidth`, `maxWidth`, `minHeight`, `maxHeight` and `ratio` (width / height). It reads the header of PNG, GIF, WebP and JPEG files. Any other file fails. A ratio passes when it is off by less than one pixel.

With fluent schemas, use `v.file()`. Sizes there are in bytes:

```dart
v.file()
    .maxSize(2 * 1024 * 1024) // 2 MB
    .mimeTypes(<String>['image/jpeg', 'image/png'])
    .dimensions(minWidth: 100, maxWidth: 2000);
```

The fluent methods are `maxSize`, `minSize`, `mimes`, `mimeTypes`, `dimensions`, `image` and `extensions`.

## Database

These rules come from `dox_orm`. They run after all other checks pass:

| Annotation | Code | Message |
| --- | --- | --- |
| `@Unique(table, {column, ignoreParam, ignoreColumn, connection})` | `unique` | `The {field} has already been taken` |
| `@Exists(table, {column, connection})` | `exists` | `The selected {field} is invalid` |

- The default column of `@Unique` is the input key. The default column of `@Exists` is id.
- They read the table, not the model, so soft-deleted rows count too.
- `ignoreParam: 'id'` skips the row where `ignoreColumn` (default id) equals the path param `{id}`.

See [Database rules](validation.md#database-rules-unique-and-exists). In a fluent schema, use `v.string().unique('users', column: 'email')` and `v.int().exists('teams')`. See [Fluent schemas](../packages/validation.md#more-rules).

## Keys and DTO options

These options change how the full DTO reads its input:

| Annotation | Does |
| --- | --- |
| `@Name('emailAddress')` | the input key for this field. Default: the field name in snake case. |
| `@Dto()` | marks the class. |
| `@Dto(source: Source.query)` | where to read: `Source.auto` (default), `Source.query`, `Source.body`. |
| `@Dto(keyCase: KeyCase.field)` | keys: `KeyCase.snake` (default) or `KeyCase.field` (the Dart name as it is). |
| `@Dto(strict: true)` | unknown keys are errors. Default false: they are dropped. |
| `@Dto(emptyStringsToNull: true)` | "" is read as null, not as missing. Default false. |
| `@Dto(trim: true)` | trims every string field and text item, like `@Trim()` on each. Default false. |
| `@Dto(coerce: true)` | a JSON body can send text for numbers and bools, like a form. Default false. |
| `@Dto(messages: {...})` | messages by code or `key.code`. A dotted path like `address.city.required` or `tags.*.required` works too. See [Short rule names](validation.md#short-rule-names-in-message-keys). |
| `@Dto(attributes: {...})` | the names shown for `{field}`, by key. See [Names for field](validation.md#names-for-field). |
| `@Describe('...')` | on a field: the description of the field in the JSON Schema. |

A nested DTO uses its own `trim` and `coerce`. A `///` doc comment on a field also becomes its description. `@Describe` wins over it. The OpenAPI docs and MCP tools show it:

```dart
@Describe('Category ID (see list_categories).')
final int categoryId;
```

## Types in detail

This is how each field type reads input. The short table is in [Field types](dto.md#field-types).

- JSON is strict. In a JSON body, "18" is not an integer, and you get the error `integer`. With `@Dto(coerce: true)`, JSON is read like form text for numbers and bools, and a bool also takes 1 and 0.
- Query and form data are text. Dox changes the text into the field type first.
- `int` takes 18 or 18.0, never a fraction.
- `bool` in text takes true, 1, yes, on and false, 0, no, off, in any case.
- `DateTime` takes 2024-01-31 or 2024-01-31T10:00:00Z. A value with no time zone is read as UTC, and the result is always UTC. A timestamp number is not allowed.
- An enum matches the Dart name exactly, so "Admin" does not match `Role.admin`.
- `Object?` and `dynamic` take any value, with no check.
- `Map<String, dynamic>` must be an object. Its values are not checked.
- In query and form data, one value for a list field gives a list with one item. Bracket indexes are sorted and packed, so `items[3]` alone gives a list with one item.
- In query and form data, a list can have at most 1000 items, and keys can nest at most 10 levels. More gives 422 with the key `_root`.

## Body types

The content type of the body decides how Dox reads it:

| Body | Result |
| --- | --- |
| `application/json` (or any `+json` type) | read with strict JSON types |
| `application/x-www-form-urlencoded`, `multipart/form-data` | read as text, then converted |
| any other content type | 415 Unsupported Media Type |
| JSON that is not valid | 400 Bad Request |
| JSON that is not an object (like `[1, 2]`) | 422 with the key `_root` |

## The order of checks

Dox checks the input in four steps:

1. Read the input and convert types. Change text (`@Trim`, `@Lowercase`, `@Uppercase`). Find missing required fields and run the rules that read other keys, except `@Confirmed` and `@Same`.
2. The field rules, top to bottom. The first rule that fails stops the other rules of that field. A fluent schema runs all rules, unless you add `.bail()`. See [Stop at the first error](../packages/validation.md#stop-at-the-first-error).
3. The `validate()` method, nested DTOs first.
4. Async rules (`@Unique`, `@Exists`, your `AsyncRule`), one at a time, in field order.

Each step runs only when the step before it had no errors, so the database never gets input that is already wrong. Inside one step, Dox collects the errors of all fields.

## What the generator checks

The build stops with a clear error when:

- a field is not final, or is not a parameter of the unnamed constructor,
- a field type is not supported (see [Field types](dto.md#field-types)),
- a rule does not fit the field type (like `@Email()` on an `int`),
- a `Maybe<T>` field has no `const Maybe.missing()` default,
- a required, present, prohibited or exclude rule, or `@OrDefault()`, is on a field that is always required,
- a rule that reads another key names a Dart field (like `accountType`) instead of its input key (`account_type`),
- a date rule has a text that is not a date, a word or another date field,
- `@DateFormatted` has a letter it does not know,
- `@Regex` has a bad pattern, or a size text is bad,
- two `@Dto` classes in the app have the same name,
- the class is generic, or extends another class (other than `Object`).

## Next steps

- [Validation](validation.md): messages, custom rules and checks across fields.
- [DTOs](dto.md): make and use a DTO.
- [Validation package](../packages/validation.md): fluent schemas.

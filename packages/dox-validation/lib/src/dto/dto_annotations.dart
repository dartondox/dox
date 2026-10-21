// Annotations for DTO classes. `dox_builder` reads them and writes the
// checks. They do nothing at runtime by themselves.
//
// ```dart
// @Dto()
// class CreateUser {
//   @Length(min: 3, max: 50)
//   final String name;
//
//   const CreateUser({required this.name});
//
//   static const DtoSchema<CreateUser> schema = $CreateUserDto;
// }
// ```

/// Where a DTO reads its input.
enum Source {
  /// `GET`, `HEAD` and `DELETE` read the query, the others the body.
  auto,

  /// Always the query string.
  query,

  /// Always the body.
  body,
}

/// How a field name becomes the input key.
enum KeyCase {
  /// `firstName` reads `first_name`. The default.
  snake,

  /// `firstName` reads `firstName`.
  field,
}

/// Marks a class as a DTO: typed, checked input.
class Dto {
  const Dto({
    this.source = Source.auto,
    this.keyCase = KeyCase.snake,
    this.strict = false,
    this.messages = const <String, String>{},
  });

  /// Where to read the input. See [Source].
  final Source source;

  /// How field names become keys. See [KeyCase].
  final KeyCase keyCase;

  /// `true`: an unknown key is an error. `false`: it is dropped.
  final bool strict;

  /// Messages by `code` or by `key.code`, like `email.required`.
  final Map<String, String> messages;
}

/// The input key of this field. Default: the field name in snake_case.
class Name {
  const Name(this.key);

  final String key;
}

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------

/// Number of characters: `@Length(min: 3, max: 50)`. Give one or both.
class Length {
  const Length({this.min, this.max, this.message});

  final int? min;
  final int? max;
  final String? message;
}

/// At least [value] characters.
class MinLength {
  const MinLength(this.value, {this.message});

  final int value;
  final String? message;
}

/// At most [value] characters.
class MaxLength {
  const MaxLength(this.value, {this.message});

  final int value;
  final String? message;
}

/// An email address.
class Email {
  const Email({this.message});

  final String? message;
}

/// An `http` or `https` url with a host.
class Url {
  const Url({this.message});

  final String? message;
}

/// A UUID, any version.
class Uuid {
  const Uuid({this.message});

  final String? message;
}

/// An IPv4 or IPv6 address.
class Ip {
  const Ip({this.message});

  final String? message;
}

/// The whole text must match [pattern]. No `^` and `$` needed.
class Regex {
  const Regex(this.pattern, {this.message});

  final String pattern;
  final String? message;
}

/// One of [values]. Works for text and numbers.
class In {
  const In(this.values, {this.message});

  final List<Object> values;
  final String? message;
}

/// Not one of [values]. Works for text and numbers.
class NotIn {
  const NotIn(this.values, {this.message});

  final List<Object> values;
  final String? message;
}

/// The text starts with [prefix].
class StartsWith {
  const StartsWith(this.prefix, {this.message});

  final String prefix;
  final String? message;
}

/// The text ends with [suffix].
class EndsWith {
  const EndsWith(this.suffix, {this.message});

  final String suffix;
  final String? message;
}

/// Only ASCII letters.
class Alpha {
  const Alpha({this.message});

  final String? message;
}

/// Only ASCII letters and digits.
class AlphaNumeric {
  const AlphaNumeric({this.message});

  final String? message;
}

/// Only ASCII letters, `-` and `_`.
class AlphaDash {
  const AlphaDash({this.message});

  final String? message;
}

// ---------------------------------------------------------------------------
// Change text
// ---------------------------------------------------------------------------

/// Remove spaces at the start and the end.
class Trim {
  const Trim();
}

/// Make the text lower case.
class Lowercase {
  const Lowercase();
}

/// Make the text upper case.
class Uppercase {
  const Uppercase();
}

/// Keep `""` as a value. Without it, `""` counts as missing.
class AllowEmpty {
  const AllowEmpty();
}

// ---------------------------------------------------------------------------
// Numbers
// ---------------------------------------------------------------------------

/// At least [value].
class Min {
  const Min(this.value, {this.message});

  final num value;
  final String? message;
}

/// At most [value].
class Max {
  const Max(this.value, {this.message});

  final num value;
  final String? message;
}

/// From [min] to [max].
class Range {
  const Range(this.min, this.max, {this.message});

  final num min;
  final num max;
  final String? message;
}

/// Greater than 0.
class Positive {
  const Positive({this.message});

  final String? message;
}

/// Greater than [value] (exclusive).
class GreaterThan {
  const GreaterThan(this.value, {this.message});

  final num value;
  final String? message;
}

/// Less than [value] (exclusive).
class LessThan {
  const LessThan(this.value, {this.message});

  final num value;
  final String? message;
}

// ---------------------------------------------------------------------------
// Lists
// ---------------------------------------------------------------------------

/// At least [value] items.
class MinItems {
  const MinItems(this.value, {this.message});

  final int value;
  final String? message;
}

/// At most [value] items.
class MaxItems {
  const MaxItems(this.value, {this.message});

  final int value;
  final String? message;
}

/// No item twice.
class UniqueItems {
  const UniqueItems({this.message});

  final String? message;
}

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

/// After [date] (exclusive). An ISO 8601 date, or `'now'`.
class After {
  const After(this.date, {this.message});

  final String date;
  final String? message;
}

/// Before [date] (exclusive). An ISO 8601 date, or `'now'`.
class Before {
  const Before(this.date, {this.message});

  final String date;
  final String? message;
}

// ---------------------------------------------------------------------------
// Files
// ---------------------------------------------------------------------------

/// At most [size], like `'2MB'`. Units: `B`, `KB`, `MB`, `GB`.
class MaxSize {
  const MaxSize(this.size, {this.message});

  final String size;
  final String? message;
}

/// One of the file types [types] (extensions, like `pdf`).
/// The real type comes from the first bytes of the file.
class Mimes {
  const Mimes(this.types, {this.message});

  final List<String> types;
  final String? message;
}

/// An image: jpg, jpeg, png, gif, webp or bmp. Not svg.
class Image {
  const Image({this.message});

  final String? message;
}

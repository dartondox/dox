// Annotations for request classes (DTOs).
// A DTO is a plain Dart class with typed fields:
//
// ```
// @Dto()
// class CreateUser {
//   @Length(min: 2, max: 50)
//   final String name;
//
//   @Email()
//   final String email;
//
//   /// nullable: optional
//   final String? bio;
//
//   /// default value: optional
//   final Role role;
//
//   CreateUser({required this.name, required this.email, this.bio,
//       this.role = Role.user});
// }
// ```
//
// - A nullable field is optional. A field with a constructor default is
//   optional and gets that default.
// - An enum field allows only the enum value names.
// - A field can be another `@Dto` class or a `List` of one.
//
// `dox_builder` reads these at build time, for the OpenAPI docs now.

/// Marks a class as a request class (DTO).
class Dto {
  const Dto();
}

/// Length of a text: `@Length(min: 2, max: 50)`.
class Length {
  final int? min;
  final int? max;

  const Length({this.min, this.max});
}

/// The text must be an email address.
class Email {
  const Email();
}

/// The number must be at least [value].
class Min {
  final num value;

  const Min(this.value);
}

/// The number must be at most [value].
class Max {
  final num value;

  const Max(this.value);
}

/// The text must match the regular expression [regex].
///
/// Note: in a file that imports `dox_core`, the name `Pattern` means
/// this class, not `Pattern` of `dart:core`. If you need the
/// `dart:core` one, add `hide Pattern` to the `dox_core` import.
class Pattern {
  final String regex;

  const Pattern(this.regex);
}

/// The list must have at least [value] items.
class MinItems {
  final int value;

  const MinItems(this.value);
}

/// The list must have at most [value] items.
class MaxItems {
  final int value;

  const MaxItems(this.value);
}

/// Remove spaces at the start and the end of the text.
class Trim {
  const Trim();
}

/// A JSON Schema format, like `uri`, `uuid` or `date-time`.
class Format {
  final String name;

  const Format(this.name);
}

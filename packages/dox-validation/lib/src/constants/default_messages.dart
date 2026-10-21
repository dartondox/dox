/// Default English message templates.
///
/// Placeholders: `{field}` is the last key in the path, `{value}` is the
/// input value. Rules add their own, like `{min}` and `{max}`.
/// Old dox messages with `%s` also work (see [MessageResolver.format]).
class DefaultMessages {
  static const String required = 'The {field} is required';
  static const String string = 'The {field} must be a string';
  static const String integer = 'The {field} must be an integer';
  static const String numeric = 'The {field} must be a number';
  static const String double = 'The {field} must be a double';
  static const String boolean = 'The {field} must be a boolean';
  static const String date = 'The {field} must be a date';
  static const String array = 'The {field} must be an array';
  static const String object = 'The {field} must be an object';

  /// The whole request body is not an object (the `_root` key).
  static const String rootObject = 'The request body must be a JSON object.';
  static const String json = 'The {field} is not a valid json';
  static const String file = 'The {field} must be a file';
  static const String fileExtension =
      'The {field} is either invalid or unsupported extension';
  static const String inList =
      'The selected {field} is invalid. Valid options are {values}';
  static const String notIn = 'The {field} field cannot be {value}';
  static const String literal = 'The {field} must be {expected}';
  static const String union = 'The {field} does not match any allowed type';
  static const String unrecognizedKeys = 'The {field} has unknown keys: {keys}';
  static const String notAllowed = 'The {field} field is not allowed';
  static const String custom = 'The {field} is invalid';

  static const String minLength =
      'The {field} must be at least {min} characters';
  static const String maxLength =
      'The {field} may not be greater than {max} characters';
  static const String length =
      'The {field} must be exactly {length} characters';
  static const String lengthBetween =
      'The {field} must be between {min} and {max} characters';
  static const String email = 'The {field} is not a valid email';
  static const String url = 'The {field} must be a url';
  static const String uuid = 'The {field} is invalid uuid';
  static const String ip = 'The {field} must be an ip address';
  static const String regex = 'The {field} format is invalid';
  static const String startWith = 'The {field} must start with {prefix}';
  static const String endWith = 'The {field} must end with {suffix}';
  static const String includes = 'The {field} must include {text}';
  static const String alpha = 'The {field} must be an alphabetic';
  static const String alphaDash =
      'The {field} must be only alphabetic and dash';
  static const String alphaNumeric =
      'The {field} must be only alphabetic and number';
  static const String datetime = 'The {field} must be a valid date time';

  static const String min = 'The {field} must be greater than or equal {min}';
  static const String max = 'The {field} must be less than or equal {max}';
  static const String between = 'The {field} must be between {min} and {max}';
  static const String greaterThan = 'The {field} must be greater than {min}';
  static const String lessThan = 'The {field} must be less than {max}';
  static const String multipleOf = 'The {field} must be a multiple of {factor}';

  static const String minItems = 'The {field} must have at least {min} items';
  static const String maxItems =
      'The {field} may not have more than {max} items';
  static const String uniqueItems = 'The {field} must not have duplicate items';

  static const String after = 'The {field} must be a date after {date}';
  static const String before = 'The {field} must be a date before {date}';

  static const String maxSize = 'The {field} may not be larger than {max}';
  static const String mimes = 'The {field} must be a file of type: {types}';
  static const String image = 'The {field} must be an image';
  static const String positive = 'The {field} must be greater than 0';

  static const String afterOrEqual =
      'The {field} must be a date after or equal to {date}';
  static const String beforeOrEqual =
      'The {field} must be a date before or equal to {date}';
}

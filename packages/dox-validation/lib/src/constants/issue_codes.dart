/// Codes used in [ValidationIssue.code].
///
/// The same codes work for DTOs and fluent schemas, so one message map
/// works for both.
class IssueCodes {
  static const String required = 'required';
  static const String string = 'string';
  static const String integer = 'integer';
  static const String numeric = 'numeric';
  static const String double = 'double';
  static const String boolean = 'boolean';
  static const String date = 'date';
  static const String array = 'array';
  static const String object = 'object';
  static const String json = 'json';
  static const String file = 'file';
  static const String image = 'image';
  static const String inList = 'in';
  static const String notIn = 'not_in';
  static const String literal = 'literal';
  static const String union = 'union';
  static const String unrecognizedKeys = 'unrecognized_keys';
  static const String custom = 'custom';

  static const String minLength = 'min_length';
  static const String maxLength = 'max_length';
  static const String length = 'length';
  static const String lengthBetween = 'length_between';
  static const String email = 'email';
  static const String url = 'url';
  static const String uuid = 'uuid';
  static const String ip = 'ip';
  static const String regex = 'regex';
  static const String startWith = 'start_with';
  static const String endWith = 'end_with';
  static const String includes = 'includes';
  static const String alpha = 'alpha';
  static const String alphaDash = 'alpha_dash';
  static const String alphaNumeric = 'alpha_numeric';
  static const String datetime = 'datetime';

  static const String min = 'min';
  static const String max = 'max';
  static const String between = 'between';
  static const String greaterThan = 'greater_than';
  static const String lessThan = 'less_than';
  static const String multipleOf = 'multiple_of';

  static const String minItems = 'min_items';
  static const String maxItems = 'max_items';
  static const String uniqueItems = 'unique_items';

  static const String after = 'after';
  static const String before = 'before';

  static const String maxSize = 'max_size';
  static const String mimes = 'mimes';

  static const String afterOrEqual = 'after_or_equal';
  static const String beforeOrEqual = 'before_or_equal';
}

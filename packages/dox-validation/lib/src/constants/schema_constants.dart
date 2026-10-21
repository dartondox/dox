/// Values for the Standard Schema interface and JSON Schema export.
class SchemaConstants {
  /// Vendor name reported by every dox schema.
  static const String vendor = 'dox';

  /// Standard Schema interface version.
  static const int standardVersion = 1;

  /// JSON Schema dialect that `toJsonSchema()` follows.
  static const String jsonSchemaDialect =
      'https://json-schema.org/draft/2020-12/schema';

  /// Words that coerce to `true`.
  static const List<String> trueWords = <String>['true', '1', 'yes', 'on'];

  /// Words that coerce to `false`.
  static const List<String> falseWords = <String>['false', '0', 'no', 'off'];

  /// Image types for `@Image()` and `v.file().image()`.
  /// No `svg`: an SVG file can hold scripts.
  static const List<String> imageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  ];
}

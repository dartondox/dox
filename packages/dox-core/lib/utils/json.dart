import 'dart:convert';

/// encodes json straight to utf8 bytes, without building a String first.
/// 8 KB chunks: most bodies fit in one, so there is no join.
final JsonUtf8Encoder _jsonUtf8Encoder = JsonUtf8Encoder(
  null,
  advanceEncode,
  8192,
);

/// decodes utf8 bytes straight into json, without a middle String.
final Converter<List<int>, Object?> _jsonUtf8Decoder = utf8.decoder.fuse(
  json.decoder,
);

/// Small helper to turn data into JSON and JSON back into data.
///
/// It works with a `String` or with UTF-8 bytes.
///
/// ```dart
/// String text = JSON.stringify({'name': 'dox'});
/// List<int> bytes = JSON.bytes({'name': 'dox'});
/// Map<String, dynamic> data = JSON.parse(text);
/// ```
class JSON {
  /// Turns [value] into a JSON `String`.
  ///
  /// A `DateTime` becomes an ISO 8601 string.
  /// Any other object must have a `toJson()` method.
  /// A value with no `toJson()` throws a `JsonUnsupportedObjectError`.
  ///
  /// ```dart
  /// JSON.stringify({'name': 'dox'}); // {"name":"dox"}
  /// JSON.stringify({'at': DateTime.utc(2024)}); // {"at":"2024-01-01T00:00:00.000Z"}
  /// JSON.stringify(user); // calls user.toJson()
  /// ```
  static String stringify(Object? value) {
    return const JsonEncoder(advanceEncode).convert(value);
  }

  /// Turns [value] into UTF-8 bytes, in one pass.
  ///
  /// No `String` is built in between. It follows the same rules as
  /// [stringify].
  /// Use it for sockets, files, queues and HTTP client bodies.
  ///
  /// Do not return it from a controller. Dox already turns a `Map`, a `List`
  /// or a model into JSON bytes for the response.
  ///
  /// ```dart
  /// List<int> body = JSON.bytes({'name': 'dox'});
  /// await File('data.json').writeAsBytes(body);
  /// ```
  static List<int> bytes(Object? value) {
    return _jsonUtf8Encoder.convert(value);
  }

  /// Reads JSON from a `String` or from UTF-8 bytes.
  ///
  /// Bytes are read in one pass. No full `String` is built. When you have
  /// both, prefer bytes. For example, use `res.bodyBytes` instead of
  /// `res.body` from an HTTP client.
  ///
  /// The result is a `Map`, `List`, `String`, `num`, `bool` or `null`.
  /// JSON has no date type, so a date comes back as a `String`.
  ///
  /// Throws a `FormatException` for bad JSON or bad UTF-8.
  /// Throws an `ArgumentError` for any other type of [input].
  ///
  /// ```dart
  /// Map<String, dynamic> a = JSON.parse('{"name":"dox"}');
  /// Map<String, dynamic> b = JSON.parse(res.bodyBytes);
  /// ```
  static dynamic parse(Object input) {
    if (input is String) {
      return jsonDecode(input);
    }
    if (input is List<int>) {
      return _jsonUtf8Decoder.convert(input);
    }
    throw ArgumentError.value(
      input,
      'input',
      'must be a String or a List<int> of UTF-8 bytes',
    );
  }
}

dynamic advanceEncode(dynamic object) {
  if (object is DateTime) {
    return object.toIso8601String();
  }
  return object.toJson();
}

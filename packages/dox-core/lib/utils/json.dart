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

/// Small helper to turn values into JSON (a String or UTF-8 bytes) and back.
class JSON {
  /// Same as `jsonEncode`. It also turns a `DateTime` into an ISO 8601
  /// string. It calls `toJson()` on any other object that has it.
  static String stringify(dynamic object) {
    return const JsonEncoder(advanceEncode).convert(object);
  }

  /// Same as `jsonDecode`.
  /// A date comes back as a String, because JSON has no date type.
  static dynamic parse(String object) {
    return jsonDecode(object);
  }

  /// Like [stringify], but gives UTF-8 bytes. No String is built in between.
  /// Use it for HTTP, sockets, files and cache. Use [stringify] when you
  /// need a String.
  static List<int> bytes(Object? value) {
    return _jsonUtf8Encoder.convert(value);
  }

  /// Like [parse], but reads UTF-8 bytes. No String is built in between.
  /// Use it for HTTP, sockets, files and cache. Use [parse] when you have
  /// a String.
  /// Throws a `FormatException` for bad UTF-8 or bad JSON.
  /// A date comes back as a String, because JSON has no date type.
  static Object? parseBytes(List<int> bytes) {
    return _jsonUtf8Decoder.convert(bytes);
  }
}

dynamic advanceEncode(dynamic object) {
  if (object is DateTime) {
    return object.toIso8601String();
  }
  return object.toJson();
}

import 'dart:convert';

/// Small helper to turn values into JSON text and back.
class JSON {
  /// Same as `jsonEncode`. It also turns a `DateTime` into an ISO 8601
  /// string. It calls `toJson()` on any other object that has it.
  static String stringify(dynamic object) {
    return jsonEncode(object, toEncodable: advanceEncode);
  }

  /// Same as `jsonDecode`.
  static dynamic parse(String object) {
    return jsonDecode(object);
  }
}

dynamic advanceEncode(dynamic object) {
  if (object is DateTime) {
    return object.toIso8601String();
  }
  return object.toJson();
}

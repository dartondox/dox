import 'dart:convert';

class JSON {
  static String stringify(dynamic object) {
    return jsonEncode(object, toEncodable: advanceEncode);
  }

  static dynamic parse(String object) {
    return jsonDecode(object);
  }
}

dynamic advanceEncode(dynamic object) {
  if (object is DateTime) {
    return object.toIso8601String();
  }
  return object;
}

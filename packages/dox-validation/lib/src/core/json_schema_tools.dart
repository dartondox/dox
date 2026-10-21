/// Small helpers for building JSON Schema maps.
class JsonSchemaTools {
  /// Add `description` and `examples` to [json].
  static Map<String, dynamic> addMeta(
    Map<String, dynamic> json,
    String? description,
    List<Object?> examples,
  ) {
    if (description != null) {
      json['description'] = description;
    }
    if (examples.isNotEmpty) {
      List<Object?> encoded = <Object?>[];
      for (Object? example in examples) {
        encoded.add(toJsonValue(example));
      }
      json['examples'] = encoded;
    }
    return json;
  }

  /// Make [json] also accept `null`.
  ///
  /// `{'type': 'string'}` becomes `{'type': ['string', 'null']}`.
  /// Other shapes are wrapped in `anyOf`.
  static Map<String, dynamic> makeNullable(Map<String, dynamic> json) {
    Object? type = json['type'];
    bool simple = !json.containsKey('enum') && !json.containsKey('const');
    if (simple && type is String) {
      json['type'] = <String>[type, 'null'];
      return json;
    }
    if (simple && type is List<Object?>) {
      if (!type.contains('null')) {
        json['type'] = <Object?>[...type, 'null'];
      }
      return json;
    }
    return <String, dynamic>{
      'anyOf': <Map<String, dynamic>>[
        json,
        <String, dynamic>{'type': 'null'},
      ],
    };
  }

  /// Turn a Dart value into a JSON safe value. Dates become ISO text.
  static Object? toJsonValue(Object? value) {
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is List<Object?>) {
      List<Object?> list = <Object?>[];
      for (Object? item in value) {
        list.add(toJsonValue(item));
      }
      return list;
    }
    if (value is Map<Object?, Object?>) {
      Map<String, Object?> map = <String, Object?>{};
      for (MapEntry<Object?, Object?> entry in value.entries) {
        map[entry.key.toString()] = toJsonValue(entry.value);
      }
      return map;
    }
    return value;
  }

  /// The JSON Schema `type` for a list of enum values, or `null` if mixed.
  static String? typeOfValues(List<Object?> values) {
    if (values.isEmpty) {
      return null;
    }
    bool allStrings = true;
    bool allInts = true;
    bool allNums = true;
    bool allBools = true;
    for (Object? value in values) {
      allStrings = allStrings && value is String;
      allInts = allInts && value is int;
      allNums = allNums && value is num;
      allBools = allBools && value is bool;
    }
    if (allStrings) {
      return 'string';
    }
    if (allInts) {
      return 'integer';
    }
    if (allNums) {
      return 'number';
    }
    if (allBools) {
      return 'boolean';
    }
    return null;
  }
}

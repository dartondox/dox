import 'package:analyzer/dart/constant/value.dart';

/// Dart code that is written as it is, for example `i0.createUser`.
class DartCode {
  final String code;

  const DartCode(this.code);
}

/// Writes JSON-like values (maps, lists, strings, numbers, bools, null)
/// and [DartCode] as Dart source code.
class DartLiteral {
  const DartLiteral();

  /// [value] as Dart code. Maps are `Map<String, dynamic>`, lists are
  /// `List<dynamic>`.
  String write(Object? value) {
    if (value == null) return 'null';
    if (value is DartCode) return value.code;
    if (value is String) return string(value);
    if (value is bool || value is num) return '$value';
    if (value is Map) {
      StringBuffer out = StringBuffer('<String, dynamic>{');
      for (MapEntry<Object?, Object?> entry in value.entries) {
        out.write('${string('${entry.key}')}: ${write(entry.value)}, ');
      }
      out.write('}');
      return out.toString();
    }
    if (value is List) {
      StringBuffer out = StringBuffer('<dynamic>[');
      for (Object? item in value) {
        out.write('${write(item)}, ');
      }
      out.write(']');
      return out.toString();
    }
    throw ArgumentError.value(value, 'value', 'Not a JSON value');
  }

  /// A list of strings as `<String>[...]`.
  String strings(List<String> values) {
    StringBuffer out = StringBuffer('<String>[');
    for (String value in values) {
      out.write('${string(value)}, ');
    }
    out.write(']');
    return out.toString();
  }

  /// A string map as `<String, String>{...}`.
  String stringMap(Map<String, String> values) {
    StringBuffer out = StringBuffer('<String, String>{');
    for (MapEntry<String, String> entry in values.entries) {
      out.write('${string(entry.key)}: ${string(entry.value)}, ');
    }
    out.write('}');
    return out.toString();
  }

  /// [text] in single quotes, with `\`, `'`, `$` and new lines escaped.
  String string(String text) {
    String escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return "'$escaped'";
  }

  /// A constant value from an annotation as a JSON-like value.
  /// Returns null for values that are not JSON-like.
  Object? fromConstant(DartObject? object) {
    if (object == null || object.isNull) return null;
    String? text = object.toStringValue();
    if (text != null) return text;
    bool? flag = object.toBoolValue();
    if (flag != null) return flag;
    int? whole = object.toIntValue();
    if (whole != null) return whole;
    double? real = object.toDoubleValue();
    if (real != null) return real;
    List<DartObject>? list = object.toListValue();
    if (list != null) {
      List<Object?> out = <Object?>[];
      for (DartObject item in list) {
        out.add(fromConstant(item));
      }
      return out;
    }
    Map<DartObject?, DartObject?>? map = object.toMapValue();
    if (map != null) {
      Map<String, Object?> out = <String, Object?>{};
      for (MapEntry<DartObject?, DartObject?> entry in map.entries) {
        String? key = entry.key?.toStringValue();
        if (key != null) out[key] = fromConstant(entry.value);
      }
      return out;
    }
    return null;
  }
}

import 'package:dox_core/dox_core.dart';

class Rules {
  static bool isRequired(Map<String, dynamic> data, dynamic value, [args]) {
    if (value == null) {
      return false;
    }
    if (value is List) {
      return value.isNotEmpty;
    }
    return value.toString().isNotEmpty;
  }

  static bool isEmail(Map<String, dynamic> data, dynamic value, [args]) {
    final emailRegex = RegExp(
        r'^[\w-]+(\.[\w-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*(\.[a-zA-Z]{2,})$');
    return emailRegex.hasMatch(value.toString());
  }

  static bool isString(Map<String, dynamic> data, dynamic value, [args]) {
    return value is String;
  }

  static bool isNumeric(Map<String, dynamic> data, dynamic value, [args]) {
    try {
      num.parse(value.toString());
      return true;
    } catch (e) {
      return false;
    }
  }

  static bool isIp(Map<String, dynamic> data, dynamic value, [args]) {
    final ipAddressRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return ipAddressRegex.hasMatch(value.toString());
  }

  static bool isBoolean(Map<String, dynamic> data, dynamic value, [args]) {
    return value is bool;
  }

  static bool isInteger(Map<String, dynamic> data, dynamic value, [args]) {
    try {
      int.parse(value.toString());
      return true;
    } catch (e) {
      return false;
    }
  }

  static bool isDouble(Map<String, dynamic> data, dynamic value, [args]) {
    try {
      double.parse(value.toString());
      return true;
    } catch (e) {
      return false;
    }
  }

  static bool isArray(Map<String, dynamic> data, dynamic value, [args]) {
    return value is List;
  }

  static bool isJson(Map<String, dynamic> data, dynamic value, [args]) {
    return value is Map;
  }

  static bool isAlpha(Map<String, dynamic> data, dynamic value, [args]) {
    final alphabeticRegex = RegExp(r'^[a-zA-Z]+$');
    return alphabeticRegex.hasMatch(value.toString());
  }

  static bool isAlphaDash(Map<String, dynamic> data, dynamic value, [args]) {
    final alphaDashRegex = RegExp(r'^[a-zA-Z-_]+$');
    return alphaDashRegex.hasMatch(value.toString());
  }

  static bool isAlphaNumeric(Map<String, dynamic> data, dynamic value, [args]) {
    final alphaNumericRegex = RegExp(r'^[a-zA-Z0-9]+$');
    return alphaNumericRegex.hasMatch(value.toString());
  }

  static bool isDate(Map<String, dynamic> data, dynamic value, [args]) {
    try {
      DateTime? dateTime = DateTime.tryParse(value.toString());
      return dateTime != null;
    } catch (e) {
      return false;
    }
  }

  static bool isUrl(Map<String, dynamic> data, dynamic value, [args]) {
    try {
      Uri? uri = Uri.tryParse(value);
      return uri != null && uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  static bool isUUID(Map<String, dynamic> data, dynamic value, [args]) {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(value.toString());
  }

  static bool maxLength(Map<String, dynamic> data, dynamic value, [max]) {
    if (max == null) {
      return false;
    }
    return value.toString().length < num.parse(max.toString());
  }

  static bool minLength(Map<String, dynamic> data, dynamic value, [min]) {
    if (min == null) {
      return false;
    }
    return value.toString().length > num.parse(min.toString());
  }

  static bool lengthBetween(Map<String, dynamic> data, dynamic value,
      [values]) {
    List<String> parts = values.toString().split(',');
    num value1 = num.parse(parts[0]);
    num value2 = num.parse(parts[1]);
    value = value.toString().length;
    if (value1 < value2) {
      return value >= value1 && value <= value2;
    }
    return value >= value2 && value <= value1;
  }

  static bool between(Map<String, dynamic> data, dynamic value, [values]) {
    List<String> parts = values.toString().split(',');
    num value1 = num.parse(parts[0]);
    num value2 = num.parse(parts[1]);
    value = num.parse(value.toString());
    if (value1 < value2) {
      return value >= value1 && value <= value2;
    }
    return value >= value2 && value <= value1;
  }

  static bool greaterThan(Map<String, dynamic> data, dynamic value, [compare]) {
    if (compare == null) {
      return false;
    }
    value = num.parse(value.toString());
    return value > num.parse(compare.toString());
  }

  static bool lessThan(Map<String, dynamic> data, dynamic value, [compare]) {
    if (compare == null) {
      return false;
    }
    value = num.parse(value.toString());
    return value < num.parse(compare.toString());
  }

  static bool min(Map<String, dynamic> data, dynamic value, [compare]) {
    if (compare == null) {
      return false;
    }
    value = num.parse(value.toString());
    return value >= num.parse(compare.toString());
  }

  static bool max(Map<String, dynamic> data, dynamic value, [compare]) {
    if (compare == null) {
      return false;
    }
    value = num.parse(value.toString());
    return value <= num.parse(compare.toString());
  }

  static bool inArray(Map<String, dynamic> data, dynamic value, [arr]) {
    List<String> array = arr.toString().split(',');
    return array.contains(value.toString());
  }

  static bool notInArray(Map<String, dynamic> data, dynamic value, [arr]) {
    List<String> array = arr.toString().split(',');
    return !array.contains(value.toString());
  }

  static bool startWith(Map<String, dynamic> data, dynamic value, [start]) {
    return value.toString().startsWith(start);
  }

  static bool endWith(Map<String, dynamic> data, dynamic value, [end]) {
    return value.toString().endsWith(end);
  }

  static bool confirmed(Map<String, dynamic> data, dynamic value, [key]) {
    key = key == null || key.toString().isEmpty ? 'password_confirmation' : key;
    var confirmValue = data[key];
    return confirmValue == value;
  }

  static bool requiredIf(Map<String, dynamic> data, dynamic value, [payload]) {
    List<String> parts = payload.split(',');
    String secondField = parts[0];
    String secondFieldValueFromRule = parts[1].toString();
    String? secondFieldValueFromRequest = data[secondField].toString();

    /// check only when req value and rule value are same
    if (secondFieldValueFromRule == secondFieldValueFromRequest) {
      return isRequired(data, value);
    }
    return true;
  }

  static bool requiredIfNot(Map<String, dynamic> data, dynamic value,
      [payload]) {
    List<String> parts = payload.split(',');
    String secondField = parts[0];
    String secondFieldValueFromRule = parts[1].toString();
    String? secondFieldValueFromRequest = data[secondField].toString();

    /// check only when req value and rule value are same
    if (secondFieldValueFromRule != secondFieldValueFromRequest) {
      return isRequired(data, value);
    }
    return true;
  }

  static bool isImage(Map<String, dynamic> data, dynamic value, [args]) {
    if (value is! RequestFile) {
      return false;
    }
    List<String> extensions = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'svg',
      'webp',
      'tiff',
      'ico'
    ];
    if (args.toString().isNotEmpty) {
      extensions = args.split(',');
    }
    if (extensions.contains(value.extension)) {
      return true;
    }
    return false;
  }

  /// not a file => false
  /// if added supported extension in validation, check with extension
  /// return true
  static bool isFile(Map<String, dynamic> data, dynamic value, [args]) {
    if (value is! RequestFile) {
      return false;
    }
    if (args.toString().isEmpty) {
      return true;
    }
    List<String> extensions = args.split(',');
    if (extensions.contains(value.extension)) {
      return true;
    }
    return false;
  }
}

/// Writes JSON-like data (maps, lists, strings, numbers, bools, null) as
/// block style YAML.
///
/// Strings are left plain only when they are clearly safe. All other
/// strings are written in double quotes, so a parser reads back the same
/// value and type.
class YamlEmitter {
  static final RegExp _plainSafe = RegExp(r'^[A-Za-z_][A-Za-z0-9_.\-/ ]*$');
  static const Set<String> _reserved = <String>{
    'true', 'false', 'null', 'yes', 'no', 'on', 'off', 'y', 'n', '~', //
  };

  /// Creates an emitter.
  const YamlEmitter();

  /// Returns [value] as a YAML document that ends with a new line.
  String emit(Object? value) {
    if (_isBlock(value)) {
      return '${_block(value, 0).join('\n')}\n';
    }
    return '${_scalar(value)}\n';
  }

  bool _isBlock(Object? value) {
    return (value is Map && value.isNotEmpty) ||
        (value is List && value.isNotEmpty);
  }

  /// Returns the lines for a non-empty map or list at [indent] spaces.
  List<String> _block(Object? value, int indent) {
    String pad = ' ' * indent;
    List<String> lines = <String>[];
    if (value is Map) {
      for (MapEntry<dynamic, dynamic> entry in value.entries) {
        String key = '$pad${quote('${entry.key}')}:';
        if (_isBlock(entry.value)) {
          lines.add(key);
          // A list under a key may sit at the same indent; nest it anyway.
          lines.addAll(_block(entry.value, indent + 2));
        } else {
          lines.add('$key ${_scalar(entry.value)}');
        }
      }
      return lines;
    }
    for (Object? item in value as List<Object?>) {
      if (_isBlock(item)) {
        List<String> child = _block(item, indent + 2);
        child[0] = '$pad- ${child[0].substring(indent + 2)}';
        lines.addAll(child);
      } else {
        lines.add('$pad- ${_scalar(item)}');
      }
    }
    return lines;
  }

  String _scalar(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is bool) {
      return value ? 'true' : 'false';
    }
    if (value is num) {
      return _number(value);
    }
    if (value is Map) {
      return '{}';
    }
    if (value is List) {
      return '[]';
    }
    if (value is String) {
      return quote(value);
    }
    throw ArgumentError.value(value, 'value', 'Not a JSON value');
  }

  String _number(num value) {
    if (value.isNaN) {
      return '.nan';
    }
    if (value.isInfinite) {
      return value > 0 ? '.inf' : '-.inf';
    }
    return value.toString();
  }

  /// Returns [text] as a plain scalar when safe, or in double quotes.
  String quote(String text) {
    bool plain = _plainSafe.hasMatch(text) &&
        !text.endsWith(' ') &&
        !_reserved.contains(text.toLowerCase());
    if (plain) {
      return text;
    }
    StringBuffer buffer = StringBuffer('"');
    for (int rune in text.runes) {
      buffer.write(_escape(rune));
    }
    buffer.write('"');
    return buffer.toString();
  }

  String _escape(int rune) {
    switch (rune) {
      case 0x22:
        return r'\"';
      case 0x5C:
        return r'\\';
      case 0x0A:
        return r'\n';
      case 0x09:
        return r'\t';
      case 0x0D:
        return r'\r';
    }
    bool printable = (rune >= 0x20 && rune <= 0x7E) ||
        rune == 0x85 ||
        (rune >= 0xA0 && rune <= 0xD7FF) ||
        (rune >= 0xE000 && rune <= 0xFFFD && rune != 0xFEFF) ||
        rune >= 0x10000;
    if (printable) {
      return String.fromCharCode(rune);
    }
    return '\\u${rune.toRadixString(16).padLeft(4, '0')}';
  }
}

import 'package:dox_core/dox_core.dart';

/// Turns text input (query string, form data) into nested maps and
/// lists, for a DTO.
///
/// - A repeated key gives a list: `tags=a&tags=b`.
/// - Bracket keys nest: `address[city]=x`, `tags[]=a`, `items[0][name]=x`.
/// - List indexes are sorted and packed: `items[3]` alone is one item.
///
/// At most [maxItems] items in a list and [maxDepth] levels, else 422.
class FormInput {
  const FormInput();

  static const int maxItems = 1000;
  static const int maxDepth = 10;

  /// The nested input of [pairs] (key, value), in order.
  Map<String, dynamic> parse(Iterable<MapEntry<String, Object>> pairs) {
    Map<String, dynamic> root = <String, dynamic>{};
    bool changed = false;
    for (MapEntry<String, Object> pair in pairs) {
      String key = pair.key;
      int open = key.indexOf('[');
      if (open <= 0 || !key.endsWith(']')) {
        changed = _put(root, key, pair.value) || changed;
        continue;
      }
      changed = true;
      List<String> parts = <String>[key.substring(0, open)];
      for (String part in key.substring(open + 1, key.length - 1).split('][')) {
        parts.add(part);
      }
      if (parts.length > maxDepth) _tooBig();
      Map<String, dynamic> node = root;
      for (int i = 0; i < parts.length - 1; i++) {
        String part = _index(node, parts[i]);
        Object? next = node[part];
        if (next is! Map<String, dynamic>) {
          next = <String, dynamic>{};
          node[part] = next;
        }
        node = next;
      }
      _put(node, _index(node, parts.last), pair.value);
    }
    return changed ? _packMap(root) : root;
  }

  /// The input of a query string, with repeated keys.
  Map<String, dynamic> query(Uri uri) {
    List<MapEntry<String, Object>> pairs = <MapEntry<String, Object>>[];
    for (MapEntry<String, List<String>> entry
        in uri.queryParametersAll.entries) {
      for (String value in entry.value) {
        pairs.add(MapEntry<String, Object>(entry.key, value));
      }
    }
    return parse(pairs);
  }

  /// `[]` adds a new item: its index is the next free one.
  String _index(Map<String, dynamic> node, String part) {
    if (part.isNotEmpty) {
      int? index = int.tryParse(part);
      if (index != null && (index < 0 || index >= maxItems)) _tooBig();
      return part;
    }
    if (node.length >= maxItems) _tooBig();
    return '${node.length}';
  }

  /// a repeated key becomes a list. `true` when the key was there.
  bool _put(Map<String, dynamic> node, String key, Object value) {
    Object? old = node[key];
    if (old == null) {
      node[key] = value;
      return false;
    }
    if (old is _Repeated) {
      if (old.values.length >= maxItems) _tooBig();
      old.values.add(value);
    } else {
      node[key] = _Repeated(<Object>[old, value]);
    }
    return true;
  }

  Map<String, dynamic> _packMap(Map<String, dynamic> value) {
    Map<String, dynamic> out = <String, dynamic>{};
    for (MapEntry<String, dynamic> entry in value.entries) {
      out[entry.key] = _pack(entry.value);
    }
    return out;
  }

  /// maps with only number keys become lists, sorted by the number
  Object? _pack(Object? value) {
    if (value is _Repeated) return value.values;
    if (value is! Map<String, dynamic>) return value;
    bool numbers = value.isNotEmpty;
    for (String key in value.keys) {
      if (int.tryParse(key) == null) {
        numbers = false;
        break;
      }
    }
    if (!numbers) return _packMap(value);
    List<int> keys = <int>[for (String key in value.keys) int.parse(key)]
      ..sort();
    return <Object?>[for (int key in keys) _pack(value['$key'])];
  }

  Never _tooBig() {
    throw ValidationException(
      message: <String, String>{
        '_root':
            'The input has too many items (max $maxItems) or levels '
            '(max $maxDepth)',
      },
    );
  }
}

/// values of a key that came more than once
class _Repeated {
  _Repeated(this.values);

  final List<Object> values;
}

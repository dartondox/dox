import 'sentinels.dart';

/// Reads values from nested maps and lists.
class DataPath {
  /// Read [path] from [data]. Returns [undefined] when a key is missing.
  static Object? read(Object? data, List<Object> path) {
    Object? current = data;
    for (Object part in path) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else if (current is List && part is int && part < current.length) {
        current = current[part];
      } else if (current is List && part is String) {
        int? index = int.tryParse(part);
        if (index == null || index >= current.length) {
          return undefined;
        }
        current = current[index];
      } else {
        return undefined;
      }
    }
    return current;
  }

  /// Read a dotted path like `user.address.city` from [data].
  static Object? readDotted(Object? data, String dotted) {
    return read(data, dotted.split('.'));
  }
}

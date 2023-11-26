import 'dart:convert';

Map<String, dynamic> logFilter(Map<String, dynamic> log) {
  Map<String, dynamic> newMap = jsonDecode(jsonEncode(log));
  modifyMap(newMap, 'password');
  modifyMap(newMap, 'authorization');
  return newMap;
}

void modifyMap(Map<dynamic, dynamic> map, String keyName) {
  map.forEach((dynamic key, dynamic value) {
    if (value is Map) {
      modifyMap(value, keyName);
    }
    if (key == keyName) {
      map[keyName] = '[REDACTED]';
    }
  });
}

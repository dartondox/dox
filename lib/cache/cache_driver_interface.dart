/// coverage:ignore-file

abstract class CacheDriverInterface {
  void put(String key, String value, {Duration? duration}) {}

  void forever(String key, String value) {}

  void forget(String key) {}

  void flush() {}

  String? get(String key) {
    return null;
  }

  bool has(String key) {
    return true;
  }
}

/// coverage:ignore-file

abstract class CacheDriverInterface {
  Future<void> put(String key, String value, {Duration? duration}) async {}

  Future<void> forever(String key, String value) async {}

  Future<void> forget(String key) async {}

  Future<void> flush() async {}

  Future<dynamic> get(String key) async {
    return null;
  }

  Future<bool> has(String key) async {
    return true;
  }
}

/// coverage:ignore-file

abstract class CacheDriverInterface {
  String tag = '';

  String get prefix => 'dox-framework-cache-$tag:';

  Future<void> put(String key, String value, {Duration? duration}) async {}

  Future<void> forever(String key, String value) async {}

  Future<void> forget(String key) async {}

  Future<void> flush() async {}

  void setTag(String tagName) {
    tag = tagName;
  }

  Future<dynamic> get(String key) async {
    return null;
  }

  Future<bool> has(String key) async {
    return true;
  }
}

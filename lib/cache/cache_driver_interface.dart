/// coverage:ignore-file

abstract class CacheDriverInterface {
  String tag = '';

  String get prefix => 'dox-framework-cache-$tag:';

  Future<void> put(String key, String value, {Duration? duration});

  Future<void> forever(String key, String value);

  Future<void> forget(String key);

  Future<void> flush();

  void setTag(String tagName);

  Future<dynamic> get(String key);

  Future<bool> has(String key);
}

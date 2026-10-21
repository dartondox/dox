import '../cache_driver.dart';
import '../constants/cache_constants.dart';

/// Stores nothing. Every read is a miss. Use it to turn caching off.
class NullDriver extends CacheDriver {
  NullDriver({this.prefix = CacheConstants.defaultPrefix});

  @override
  final String prefix;

  @override
  Future<dynamic> get(String key) async {
    return null;
  }

  @override
  Future<void> put(String key, Object? value, Duration? ttl) async {}

  @override
  Future<bool> add(String key, Object? value, Duration? ttl) async {
    return false;
  }

  @override
  Future<int> increment(String key, int by) async {
    return by;
  }

  @override
  Future<bool> forget(String key) async {
    return false;
  }

  @override
  Future<void> flush() async {}
}

/// Builds a [NullDriver].
class NullDriverFactory implements CacheDriverFactory {
  const NullDriverFactory();

  @override
  CacheDriver create(Map<String, dynamic> options) {
    return NullDriver(
      prefix: options[CacheConstants.prefixOption] as String? ??
          CacheConstants.defaultPrefix,
    );
  }
}

import 'package:dox_core/cache/cache_driver_interface.dart';
import 'package:dox_core/cache/drivers/redis/redis.dart';
import 'package:redis/redis.dart';

class RedisCacheDriver implements CacheDriverInterface {
  final Redis redis = Redis();

  /// tag name
  final String tag;

  RedisCacheDriver({required this.tag});

  String get _prefix => 'dox-framework-cache-$tag:';

  @override
  Future<void> flush() async {
    Command cmd = await redis.command;
    List<dynamic> res = await cmd.send_object(<dynamic>['KEYS', '$_prefix*']);
    if (res.isNotEmpty) {
      await cmd.send_object(<dynamic>['DEL', ...res]);
    }
  }

  @override
  Future<void> forever(String key, String value) async {
    await put(key, value, duration: Duration(days: 365 * 1000));
  }

  @override
  Future<void> forget(String key) async {
    Command cmd = await redis.command;
    return await cmd.send_object(<dynamic>['DEL', _prefix + key]);
  }

  @override
  Future<dynamic> get(String key) async {
    Command cmd = await redis.command;
    return await cmd.send_object(<dynamic>['GET', _prefix + key]);
  }

  @override
  Future<bool> has(String key) async {
    dynamic val = await get(key);
    return val != null ? true : false;
  }

  @override
  Future<void> put(String key, String value, {Duration? duration}) async {
    duration = duration ?? Duration(hours: 1);
    DateTime time = DateTime.now().add(duration);

    Command cmd = await redis.command;

    await cmd.send_object(<dynamic>[
      'SET',
      _prefix + key,
      value,
      'PXAT',
      time.millisecondsSinceEpoch,
    ]);
  }
}

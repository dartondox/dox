import 'package:dox_core/cache/cache_driver_interface.dart';
import 'package:redis/redis.dart';

import 'redis.dart';

class RedisCacheDriver implements CacheDriverInterface {
  Redis redis = Redis();

  @override
  String tag = '';

  @override
  String get prefix => 'dox-framework-cache-$tag:';

  RedisCacheDriver();

  @override
  void setTag(String tagName) {
    tag = tagName;
  }

  @override
  Future<void> flush() async {
    Command cmd = await redis.command;
    List<dynamic> res = await cmd.send_object(<dynamic>['KEYS', '$prefix*']);
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
    return await cmd.send_object(<dynamic>['DEL', prefix + key]);
  }

  @override
  Future<dynamic> get(String key) async {
    Command cmd = await redis.command;
    return await cmd.send_object(<dynamic>['GET', prefix + key]);
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
      prefix + key,
      value,
      'PXAT',
      time.millisecondsSinceEpoch,
    ]);
  }
}

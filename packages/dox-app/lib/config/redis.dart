import 'package:dox_core/dox_core.dart';
import 'package:ioredis/ioredis.dart';

Redis redis = Redis(
  /// Redis configuration
  /// -------------------------------
  /// Following is the configuration used by the Redis provider to connect to
  /// the redis server and execute redis commands.
  RedisOptions(
    host: Env.get('REDIS_HOST', '127.0.0.1'),
    port: Env.get('REDIS_PORT', 6379),
    db: Env.get('REDIS_DB', 0),
    // Empty means no login. ioredis sends AUTH for any non-null value.
    username: _emptyToNull(Env.get('REDIS_USERNAME', '')),
    password: _emptyToNull(Env.get('REDIS_PASSWORD', '')),
  ),
);

String? _emptyToNull(String value) {
  if (value.isEmpty) return null;
  return value;
}

import 'package:dox_app/config/env.dart';
import 'package:ioredis/ioredis.dart';

Redis redis = Redis(
  /// Redis configuration
  /// -------------------------------
  /// Following is the configuration used by the Redis provider to connect to
  /// the redis server and execute redis commands.
  RedisOptions(
    host: env.redisHost,
    port: env.redisPort,
    db: env.redisDb,
    // Empty means no login (null). ioredis sends AUTH for any non-null value.
    username: env.redisUsername,
    password: env.redisPassword,
  ),
);

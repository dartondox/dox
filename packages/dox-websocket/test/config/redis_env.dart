import 'dart:io';

import 'package:ioredis/ioredis.dart';

/// Redis for tests. Set REDIS_HOST and REDIS_PORT to change it.
String redisHost = Platform.environment['REDIS_HOST'] ?? '127.0.0.1';
int redisPort = int.parse(Platform.environment['REDIS_PORT'] ?? '6379');

Redis testRedis() {
  return Redis(RedisOptions(host: redisHost, port: redisPort));
}

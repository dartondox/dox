import 'dart:convert';
import 'dart:math';

import 'package:ioredis/ioredis.dart';

import '../cache_driver.dart';
import '../cache_lock.dart';
import '../constants/cache_constants.dart';

/// Keeps items in Redis, shared by all isolates and servers.
///
/// Uses only `Redis.sendCommand`, so the ioredis `keyPrefix` option is
/// not used. Set [prefix] instead. `flush` deletes only keys that start
/// with [prefix] (SCAN, then DEL). It never runs FLUSHDB.
/// Redis error replies throw `RedisError` (from ioredis).
class RedisDriver extends CacheDriver {
  RedisDriver(
    this.redis, {
    this.prefix = CacheConstants.defaultPrefix,
    this.maxValueBytes,
  });

  /// The connection. Inject your own or use [RedisDriverFactory].
  final Redis redis;

  @override
  final String prefix;

  /// Values bigger than this throw [ArgumentError]. Null (the default)
  /// means no limit.
  final int? maxValueBytes;

  /// Delete the lock only when the owner token matches.
  static const String _releaseScript = '''
if redis.call('GET', KEYS[1]) == ARGV[1] then
  return redis.call('DEL', KEYS[1])
end
return 0''';

  @override
  Future<dynamic> get(String key) async {
    Object? reply = await redis.sendCommand(<String>['GET', prefix + key]);
    return reply == null ? null : jsonDecode(reply.toString());
  }

  /// The stored JSON text. No decode.
  @override
  Future<String?> getRaw(String key) async {
    Object? reply = await redis.sendCommand(<String>['GET', prefix + key]);
    return reply == null ? null : CacheDriver.liveText(reply.toString());
  }

  /// One MGET for all keys.
  @override
  Future<Map<String, dynamic>> many(List<String> keys) async {
    Map<String, dynamic> result = <String, dynamic>{};
    if (keys.isEmpty) return result;
    List<dynamic> replies = await redis.sendCommand(<String>[
      'MGET',
      for (String key in keys) prefix + key,
    ]) as List<dynamic>;
    for (int i = 0; i < keys.length; i++) {
      Object? reply = replies[i];
      result[keys[i]] = reply == null ? null : jsonDecode(reply.toString());
    }
    return result;
  }

  /// All SETs in one pipeline write.
  @override
  Future<void> putMany(Map<String, Object?> values, Duration? ttl) async {
    if (values.isEmpty) return;
    RedisPipeline pipeline = redis.pipeline();
    for (MapEntry<String, Object?> entry in values.entries) {
      List<String> command = _setCommand(entry.key, entry.value, ttl);
      pipeline.call(command.first, command.sublist(1));
    }
    for (Object? reply in await pipeline.exec()) {
      if (reply is RedisError) throw reply;
    }
  }

  @override
  Future<void> put(String key, Object? value, Duration? ttl) async {
    await redis.sendCommand(_setCommand(key, value, ttl));
  }

  @override
  Future<bool> add(String key, Object? value, Duration? ttl) async {
    List<String> command = _setCommand(key, value, ttl)..add('NX');
    return await redis.sendCommand(command) == 'OK';
  }

  @override
  Future<int> increment(String key, int by) async {
    return await redis.sendCommand(<String>['INCRBY', prefix + key, '$by'])
        as int;
  }

  @override
  Future<bool> forget(String key) async {
    int deleted = await redis.sendCommand(<String>['DEL', prefix + key]) as int;
    return deleted > 0;
  }

  @override
  Future<void> flush() async {
    if (prefix.isEmpty) {
      throw StateError(
        'RedisDriver.flush needs a prefix. '
        'It will not delete the whole database.',
      );
    }
    String pattern = '${_escapeGlob(prefix)}*';
    String cursor = '0';
    do {
      List<dynamic> reply = await redis.sendCommand(<String>[
        'SCAN',
        cursor,
        'MATCH',
        pattern,
        'COUNT',
        '${CacheConstants.redisScanCount}',
      ]) as List<dynamic>;
      cursor = reply[0].toString();
      List<String> keys = List<String>.from(reply[1] as List<dynamic>);
      if (keys.isNotEmpty) {
        await redis.sendCommand(<String>['DEL', ...keys]);
      }
    } while (cursor != '0');
  }

  @override
  CacheLock lock(String name, Duration? ttl, [String? owner]) {
    return RedisLock(this, name, ttl, owner);
  }

  /// SET key owner [PX ttl] NX. True when taken.
  Future<bool> acquireLock(String name, String owner, Duration? ttl) async {
    List<String> command = <String>['SET', _lockKey(name), owner];
    if (ttl != null) {
      command.addAll(<String>['PX', _milliseconds(ttl)]);
    }
    command.add('NX');
    return await redis.sendCommand(command) == 'OK';
  }

  /// Lua check-and-delete, so only the owner frees the lock.
  Future<bool> releaseLock(String name, String owner) async {
    Object? reply = await redis.sendCommand(<String>[
      'EVAL',
      _releaseScript,
      '1',
      _lockKey(name),
      owner,
    ]);
    return reply == 1;
  }

  String _lockKey(String name) {
    return '$prefix${CacheConstants.lockKeyPart}$name';
  }

  List<String> _setCommand(String key, Object? value, Duration? ttl) {
    String text = jsonEncode(value);
    int? limit = maxValueBytes;
    if (limit != null && utf8.encode(text).length > limit) {
      throw ArgumentError('Cache value of "$key" is bigger than $limit bytes');
    }
    List<String> command = <String>['SET', prefix + key, text];
    if (ttl != null) {
      command.addAll(<String>['PX', _milliseconds(ttl)]);
    }
    return command;
  }

  /// Redis needs at least 1 ms.
  String _milliseconds(Duration ttl) {
    return '${ttl.inMilliseconds < 1 ? 1 : ttl.inMilliseconds}';
  }

  /// Escape glob characters so the prefix is matched as plain text.
  String _escapeGlob(String text) {
    return text.replaceAllMapped(RegExp(r'[*?\[\]\\]'), _escapeMatch);
  }

  String _escapeMatch(Match match) {
    return '\\${match[0]}';
  }
}

/// Lock kept in Redis. Works across processes.
class RedisLock extends CacheLock {
  RedisLock(this._driver, super.name, super.ttl, [super.owner]);

  final RedisDriver _driver;

  @override
  Future<bool> get() {
    return _driver.acquireLock(name, owner, ttl);
  }

  @override
  Future<bool> release() {
    return _driver.releaseLock(name, owner);
  }
}

/// Builds a [RedisDriver] with a new connection.
/// Options: host, port, username, password, db, tls, prefix, pool_size.
/// pool_size is the most connections to open (ioredis maxConnection).
/// ioredis shares one connection and only opens more for blocking commands.
class RedisDriverFactory implements CacheDriverFactory {
  const RedisDriverFactory();

  /// Wait before reconnect: 50 ms per try, at most 2 s.
  static Duration retryDelay(int times) {
    return Duration(milliseconds: min(times * 50, 2000));
  }

  @override
  CacheDriver create(Map<String, dynamic> options) {
    Redis redis = Redis(
      RedisOptions(
        host:
            options[CacheConstants.hostOption] as String? ??
            CacheConstants.defaultRedisHost,
        port:
            options[CacheConstants.portOption] as int? ??
            CacheConstants.defaultRedisPort,
        username: options[CacheConstants.usernameOption] as String?,
        password: options[CacheConstants.passwordOption] as String?,
        db: options[CacheConstants.dbOption] as int? ?? 0,
        secure: options[CacheConstants.tlsOption] as bool? ?? false,
        retryStrategy: retryDelay,
        maxConnection:
            options[CacheConstants.poolSizeOption] as int? ??
            CacheConstants.defaultRedisPoolSize,
      ),
    );
    return RedisDriver(
      redis,
      prefix:
          options[CacheConstants.prefixOption] as String? ??
          CacheConstants.defaultPrefix,
    );
  }
}

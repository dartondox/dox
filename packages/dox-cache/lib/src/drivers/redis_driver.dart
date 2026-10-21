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
/// with [prefix] (SCAN + DEL in a small Lua step). It never runs FLUSHDB.
class RedisDriver extends CacheDriver {
  RedisDriver(
    this.redis, {
    this.prefix = CacheConstants.defaultPrefix,
    this.maxValueBytes = CacheConstants.redisMaxValueBytes,
  });

  /// The connection. Inject your own or use [RedisDriverFactory].
  final Redis redis;

  @override
  final String prefix;

  /// Values bigger than this throw [ArgumentError]. Null means no limit.
  /// ioredis 1.0.3 can not read replies bigger than about 64 KB.
  final int? maxValueBytes;

  /// One SCAN step that deletes the keys it finds. Returns the next cursor.
  static const String _flushScript = '''
local r = redis.call('SCAN', ARGV[1], 'MATCH', ARGV[2], 'COUNT', ARGV[3])
for _, k in ipairs(r[2]) do redis.call('DEL', k) end
return r[1]''';

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

  @override
  Future<void> put(String key, Object? value, Duration? ttl) async {
    Object? reply = await redis.sendCommand(_setCommand(key, value, ttl));
    if (reply != 'OK') {
      throw StateError('Redis SET failed: $reply');
    }
  }

  @override
  Future<bool> add(String key, Object? value, Duration? ttl) async {
    List<String> command = _setCommand(key, value, ttl)..add('NX');
    return await redis.sendCommand(command) == 'OK';
  }

  @override
  Future<int> increment(String key, int by) async {
    Object? reply =
        await redis.sendCommand(<String>['INCRBY', prefix + key, '$by']);
    return _toInt(reply);
  }

  @override
  Future<bool> forget(String key) async {
    Object? reply = await redis.sendCommand(<String>['DEL', prefix + key]);
    return _toInt(reply) > 0;
  }

  @override
  Future<void> flush() async {
    if (prefix.isEmpty) {
      throw StateError('RedisDriver.flush needs a prefix. '
          'It will not delete the whole database.');
    }
    String cursor = '0';
    do {
      Object? reply = await redis.sendCommand(<String>[
        'EVAL',
        _flushScript,
        '0',
        cursor,
        '${_escapeGlob(prefix)}*',
        '${CacheConstants.redisScanCount}',
      ]);
      cursor = reply.toString();
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
    Object? reply = await redis.sendCommand(
        <String>['EVAL', _releaseScript, '1', _lockKey(name), owner]);
    return _toInt(reply) == 1;
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

  /// ioredis 1.0.3 gives integers and errors as strings. Newer versions
  /// give int and throw on errors. This handles both.
  int _toInt(Object? reply) {
    int? value = int.tryParse('$reply');
    if (value == null) {
      throw StateError('Redis error: $reply');
    }
    return value;
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
/// Options: host, port, username, password, db, tls, prefix.
class RedisDriverFactory implements CacheDriverFactory {
  const RedisDriverFactory();

  /// Wait before reconnect: 50 ms per try, at most 2 s.
  /// ioredis 1.0.3 crashes on reconnect when `RedisOptions` has no
  /// retryStrategy, so always pass one (this one is fine).
  static Duration retryDelay(int times) {
    return Duration(milliseconds: min(times * 50, 2000));
  }

  @override
  CacheDriver create(Map<String, dynamic> options) {
    Redis redis = Redis(RedisOptions(
      host: options[CacheConstants.hostOption] as String? ??
          CacheConstants.defaultRedisHost,
      port: options[CacheConstants.portOption] as int? ??
          CacheConstants.defaultRedisPort,
      username: options[CacheConstants.usernameOption] as String?,
      password: options[CacheConstants.passwordOption] as String?,
      db: options[CacheConstants.dbOption] as int? ?? 0,
      secure: options[CacheConstants.tlsOption] as bool? ?? false,
      retryStrategy: retryDelay,
    ));
    return RedisDriver(
      redis,
      prefix: options[CacheConstants.prefixOption] as String? ??
          CacheConstants.defaultPrefix,
    );
  }
}

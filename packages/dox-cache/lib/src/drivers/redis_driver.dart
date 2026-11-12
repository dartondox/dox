import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:ioredis/ioredis.dart';

import '../cache_driver.dart';
import '../cache_encrypter.dart';
import '../cache_lock.dart';
import '../constants/cache_constants.dart';

/// Keeps items in Redis, shared by all isolates and servers.
///
/// Uses only `Redis.sendCommand`, so the ioredis `keyPrefix` option is
/// not used. Set [prefix] instead. `flush` deletes only keys that start
/// with [prefix] (SCAN, then DEL). It never runs FLUSHDB.
/// Redis error replies throw `RedisError` (from ioredis).
///
/// With an [encrypter], every value is encrypted before it is written.
/// One rule keeps counters working: a plain `int` is stored as plain JSON
/// text, so `INCRBY` still works. Every other value is encrypted. On read,
/// text that is a plain integer is the number. Any other text is
/// decrypted. When that fails (wrong key or changed text), it reads as a
/// miss. `increment` on an encrypted value throws a `RedisError`, as it
/// does for any value that is not a number.
class RedisDriver extends CacheDriver {
  /// A [prefix] that does not end with `:` gets one, so the prefix
  /// `app` never matches the keys of `app2`.
  RedisDriver(
    this.redis, {
    String prefix = CacheConstants.defaultPrefix,
    this.maxValueBytes,
    this.encrypter,
  }) : prefix = withSeparator(prefix);

  /// The connection. Inject your own or use [RedisDriverFactory].
  final Redis redis;

  @override
  final String prefix;

  /// Values bigger than this throw [ArgumentError]. Null (the default)
  /// means no limit.
  final int? maxValueBytes;

  /// Encrypts the values. Null means plain JSON.
  final CacheEncrypter? encrypter;

  static final RegExp _plainInt = RegExp(r'^-?\d+$');

  /// Delete the lock only when the owner token matches.
  static const String _releaseScript = '''
if redis.call('GET', KEYS[1]) == ARGV[1] then
  return redis.call('DEL', KEYS[1])
end
return 0''';

  /// SHA1 of [_releaseScript], for EVALSHA.
  static final String _releaseSha = sha1
      .convert(utf8.encode(_releaseScript))
      .toString();

  /// [prefix] with a `:` at the end. An empty prefix stays empty.
  static String withSeparator(String prefix) {
    if (prefix.isEmpty || prefix.endsWith(':')) {
      return prefix;
    }
    return '$prefix:';
  }

  /// Close the connection and the pool connections, with no reconnect.
  /// It sends no command, so it works when Redis is down.
  @override
  Future<void> close() async {
    redis.pool.destroyAll();
    await redis.disconnect();
  }

  @override
  Future<dynamic> get(String key) async {
    Object? reply = await redis.sendCommand(<String>['GET', prefix + key]);
    return _decode(reply);
  }

  /// The stored JSON text. No decode.
  @override
  Future<String?> getRaw(String key) async {
    Object? reply = await redis.sendCommand(<String>['GET', prefix + key]);
    String? text = _plainText(reply);
    return text == null ? null : CacheDriver.liveText(text);
  }

  /// GET with no decode.
  @override
  Future<bool> has(String key) async {
    return await getRaw(key) != null;
  }

  /// One atomic GETDEL. Needs Redis 6.2 or newer.
  @override
  Future<dynamic> pull(String key) async {
    Object? reply = await redis.sendCommand(<String>['GETDEL', prefix + key]);
    return _decode(reply);
  }

  /// PEXPIRE, or PERSIST for a null [ttl].
  @override
  Future<bool> touch(String key, Duration? ttl) async {
    String fullKey = prefix + key;
    if (ttl != null) {
      return await redis.sendCommand(<String>[
            'PEXPIRE',
            fullKey,
            _milliseconds(ttl),
          ]) ==
          1;
    }
    await redis.sendCommand(<String>['PERSIST', fullKey]);
    return await redis.sendCommand(<String>['EXISTS', fullKey]) == 1;
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
      result[keys[i]] = _decode(replies[i]);
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
  /// Sends only the script hash (EVALSHA). When Redis does not know the
  /// script yet, it sends the full script once (EVAL).
  Future<bool> releaseLock(String name, String owner) async {
    List<String> args = <String>['1', _lockKey(name), owner];
    Object? reply;
    try {
      reply = await redis.sendCommand(<String>[
        'EVALSHA',
        _releaseSha,
        ...args,
      ]);
    } on RedisError catch (error) {
      if (!error.message.startsWith('NOSCRIPT')) {
        rethrow;
      }
      reply = await redis.sendCommand(<String>[
        'EVAL',
        _releaseScript,
        ...args,
      ]);
    }
    return reply == 1;
  }

  /// DEL the lock, whoever holds it.
  Future<bool> forceReleaseLock(String name) async {
    return await redis.sendCommand(<String>['DEL', _lockKey(name)]) == 1;
  }

  String _lockKey(String name) {
    return '$prefix${CacheConstants.lockKeyPart}$name';
  }

  List<String> _setCommand(String key, Object? value, Duration? ttl) {
    String plain = jsonEncode(value);
    int? limit = maxValueBytes;
    if (limit != null && utf8.encode(plain).length > limit) {
      throw ArgumentError('Cache value of "$key" is bigger than $limit bytes');
    }
    List<String> command = <String>['SET', prefix + key, _encode(value, plain)];
    if (ttl != null) {
      command.addAll(<String>['PX', _milliseconds(ttl)]);
    }
    return command;
  }

  /// The text to store. A plain int stays plain, so INCRBY works.
  String _encode(Object? value, String plain) {
    CacheEncrypter? secret = encrypter;
    return secret == null || value is int ? plain : secret.encrypt(plain);
  }

  /// The JSON text of a [reply], decrypted when needed. Null for a miss,
  /// also when it cannot be decrypted.
  String? _plainText(Object? reply) {
    if (reply == null) return null;
    String text = reply.toString();
    CacheEncrypter? secret = encrypter;
    if (secret == null || _plainInt.hasMatch(text)) return text;
    try {
      return secret.decrypt(text);
    } on Object {
      return null;
    }
  }

  dynamic _decode(Object? reply) {
    String? text = _plainText(reply);
    return text == null ? null : jsonDecode(text);
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

  @override
  Future<bool> forceRelease() {
    return _driver.forceReleaseLock(name);
  }
}

/// Builds a [RedisDriver] with a new connection.
/// Options: host, port, username, password, db, tls, prefix, pool_size,
/// max_value_bytes, encrypt (needs an encrypter).
/// pool_size is the most connections to open (ioredis maxConnection).
/// ioredis shares one connection and only opens more for blocking commands.
class RedisDriverFactory implements CacheDriverFactory {
  const RedisDriverFactory([this._encrypter]);

  final CacheEncrypter? _encrypter;

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
      maxValueBytes: options[CacheConstants.maxValueBytesOption] as int?,
      encrypter: options[CacheConstants.encryptOption] == true
          ? _encrypter
          : null,
    );
  }
}

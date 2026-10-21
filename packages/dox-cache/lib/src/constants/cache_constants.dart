/// Global constants for dox_cache.
class CacheConstants {
  /// Key prefix used when a store sets none.
  static const String defaultPrefix = 'dox_cache:';

  /// Folder of the file driver when none is given.
  static const String defaultFilePath = 'storage/cache';

  /// Built-in driver names, used in the store config.
  static const String memoryDriver = 'memory';
  static const String fileDriver = 'file';
  static const String redisDriver = 'redis';
  static const String nullDriver = 'null';

  /// Store config keys.
  static const String driverOption = 'driver';
  static const String prefixOption = 'prefix';
  static const String maxSizeOption = 'max_size';
  static const String pathOption = 'path';
  static const String hostOption = 'host';
  static const String portOption = 'port';
  static const String usernameOption = 'username';
  static const String passwordOption = 'password';
  static const String dbOption = 'db';
  static const String tlsOption = 'tls';

  /// Redis defaults.
  static const String defaultRedisHost = '127.0.0.1';
  static const int defaultRedisPort = 6379;

  /// How many keys one SCAN step looks at during flush.
  static const int redisScanCount = 500;

  /// ioredis 1.0.3 cuts replies bigger than one socket chunk (about 64 KB).
  /// The Redis driver refuses bigger values so the connection does not break.
  static const int redisMaxValueBytes = 60 * 1024;

  /// Wait time between tries in `CacheLock.block`.
  static const Duration lockPollInterval = Duration(milliseconds: 50);

  /// Key part for locks and tags.
  static const String lockKeyPart = 'lock:';
  static const String tagKeyPart = 'tag:';

  /// JSON fields in a file driver entry.
  static const String fileValueField = 'value';
  static const String fileExpiresAtField = 'expires_at';
}

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
  static const String pruneEveryOption = 'prune_every';
  static const String fsyncOption = 'fsync';
  static const String hostOption = 'host';
  static const String portOption = 'port';
  static const String usernameOption = 'username';
  static const String passwordOption = 'password';
  static const String dbOption = 'db';
  static const String tlsOption = 'tls';
  static const String poolSizeOption = 'pool_size';
  static const String redisOptionsOption = 'options';
  static const String maxValueBytesOption = 'max_value_bytes';
  static const String encryptOption = 'encrypt';

  /// Redis connection keys. They can not be set together with `options`.
  static const List<String> redisConnectionOptions = <String>[
    hostOption,
    portOption,
    usernameOption,
    passwordOption,
    dbOption,
    tlsOption,
    poolSizeOption,
  ];

  /// Redis defaults.
  static const String defaultRedisHost = '127.0.0.1';
  static const int defaultRedisPort = 6379;

  /// Most Redis connections per store when `pool_size` is not set.
  /// Same as the ioredis default.
  static const int defaultRedisPoolSize = 10;

  /// How many keys one SCAN step looks at during flush.
  static const int redisScanCount = 500;

  /// Wait time between tries in `CacheLock.block`.
  static const Duration lockPollInterval = Duration(milliseconds: 50);

  /// Key part for locks and tags.
  static const String lockKeyPart = 'lock:';
  static const String tagKeyPart = 'tag:';

  /// Lock name part for `remember(lock: true)` and `flexible`.
  static const String rememberLockPart = 'remember:';
  static const String flexibleLockPart = 'flexible:';

  /// Key part of the "created at" time that `flexible` stores.
  static const String flexibleCreatedPart = 'flexible:created:';

  /// Mark put in front of a user key, lock name or tag name that starts
  /// like an internal key. So `forget('lock:a')` can not free `lock('a')`.
  static const String escapeMark = '#';

  /// Starts of internal item keys. A user key that starts with one of
  /// these, or with [escapeMark], gets [escapeMark] in front.
  static const List<String> internalKeyStarts = <String>[
    escapeMark,
    lockKeyPart,
    tagKeyPart,
    flexibleCreatedPart,
  ];

  /// Starts of internal lock names. A user lock name that starts with one
  /// of these, or with [escapeMark], gets [escapeMark] in front.
  static const List<String> internalLockStarts = <String>[
    escapeMark,
    rememberLockPart,
    flexibleLockPart,
    fileAutoPruneLock,
  ];

  /// Lock ttl and wait time of `remember(lock: true)` and `flexible`.
  /// A compute that runs longer lets a second caller start.
  static const Duration computeLockTtl = Duration(seconds: 10);

  /// Lock ttl and wait time of file driver `add`, `increment` and `touch`.
  static const Duration fileKeyLockTtl = Duration(seconds: 5);

  /// The file driver runs `prune` once every this many writes.
  /// 0 (the default) means never.
  static const int filePruneEvery = 0;

  /// With `prune_every` 0, the file driver removes expired files, old
  /// temp files and free lock files by itself at most once in this time.
  /// One run covers all isolates and processes that share the folder.
  static const Duration fileAutoPruneInterval = Duration(hours: 1);

  /// The first auto prune of a process can start on the first write
  /// that comes at least this long after its first write. The interval lock on disk decides if it really runs, so
  /// an app that restarts often still prunes once per interval.
  static const Duration fileAutoPruneFirstDelay = Duration(minutes: 1);

  /// Lock name that makes sure only one auto prune runs per interval.
  static const String fileAutoPruneLock = 'dox:auto-prune';

  /// A temp file older than this is left from a crash, and prune
  /// deletes it. A write keeps its temp file for a few ms only.
  static const Duration fileStaleTempAge = Duration(hours: 1);

  /// End of file driver lock file names.
  static const String fileLockSuffix = '.lock';
  static const String fileKeyLockSuffix = '.klock';
  static const String fileTempSuffix = '.tmp';

  /// End of a file that `pull` or a lock moved away for a moment:
  /// `<name>.<ms>.<owner>.mv`. A rename keeps the old modified time, so
  /// the time of the move is in the name. Prune deletes one only when
  /// that time is older than [fileStaleTempAge].
  static const String fileMovedSuffix = '.mv';

  /// JSON field of a file lock.
  static const String fileOwnerField = 'owner';

  /// JSON fields in a file driver entry.
  static const String fileValueField = 'value';
  static const String fileExpiresAtField = 'expires_at';
}

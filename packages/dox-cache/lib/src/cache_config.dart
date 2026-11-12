import 'cache_lock.dart';

/// Cache settings.
///
/// ```
/// CacheConfig(
///   defaultStore: 'redis',
///   stores: <String, Map<String, dynamic>>{
///     'memory': <String, dynamic>{'driver': 'memory', 'max_size': 1000},
///     'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
///     'redis': <String, dynamic>{'driver': 'redis', 'host': '127.0.0.1'},
///   },
/// );
/// ```
class CacheConfig {
  const CacheConfig({
    required this.defaultStore,
    required this.stores,
    this.flags = const CacheFlags(),
  });

  /// Name of the store used by `CacheManager.store()`.
  final String defaultStore;

  /// Store name to options. Each needs a 'driver' option.
  final Map<String, Map<String, dynamic>> stores;

  /// Opt-in behaviors that change the defaults. All off by default.
  final CacheFlags flags;
}

/// Opt-in behaviors of the cache that change the defaults. Every flag is
/// off by default.
/// ```
/// CacheConfig(defaultStore: 'file', stores: stores,
///     flags: const CacheFlags(lockThrows: true));
/// ```
class CacheFlags {
  const CacheFlags({this.lockThrows = false});

  /// Every flag on.
  const CacheFlags.all() : lockThrows = true;

  /// `lock.block(timeout)` with no callback throws [LockTimeoutException]
  /// when the lock was not taken in time. Off: it gives false.
  /// `CacheLock.throwOnTimeout` wins over this flag.
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool lockThrows;
}

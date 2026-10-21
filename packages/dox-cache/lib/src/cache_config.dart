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
  const CacheConfig({required this.defaultStore, required this.stores});

  /// Name of the store used by `CacheManager.store()`.
  final String defaultStore;

  /// Store name to options. Each needs a 'driver' option.
  final Map<String, Map<String, dynamic>> stores;
}

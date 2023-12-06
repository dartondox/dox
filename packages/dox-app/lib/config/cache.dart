import 'package:dox_core/cache/drivers/file/file_cache_driver.dart';
import 'package:dox_core/dox_core.dart';

CacheConfig cache = CacheConfig(
  /// default cache driver
  defaultDriver: Env.get('CACHE_DRIVER', 'file'),

  /// register cache driver list
  drivers: <String, CacheDriverInterface>{
    'file': FileCacheDriver(),
  },
);

enum CacheStore {
  /// store in file
  /// cache directory will be on {project_dir}/storage/cache
  file,

  /// store in redis and make sure that redis config in set in .env
  /// username and password are optional
  /// ```
  /// REDIS_HOST=localhost
  /// REDIS_PORT=6379
  /// REDIS_TLS=false
  /// REDIS_USERNAME=
  /// REDIS_PASSWORD=
  /// ```
  redis,

  /// currently not support
  memcached,

  /// default will be file store
  systemDefault,
}

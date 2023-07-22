enum CacheStore {
  /// store in file
  /// cache directory will be on {project_dir}/storage/cache
  file,

  /// currently not support
  redis,

  /// currently not support
  memcached,

  /// default will be file store
  systemDefault,
}

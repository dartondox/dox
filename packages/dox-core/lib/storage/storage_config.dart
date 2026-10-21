import 'package:dox_storage/dox_storage.dart';

/// Storage disks for `Storage()`.
///
/// Each disk is a map of options with a `driver` key, so the config can be
/// sent to every isolate. Drivers: `local`, `s3` and `memory`.
/// ```
/// StorageConfig(
///   defaultDisk: 'local',
///   disks: {
///     'local': {'driver': 'local', 'root': 'storage', 'url': 'http://localhost:3000/files'},
///     's3': {'driver': 's3', 'bucket': 'my-bucket', 'region': 'us-east-1',
///            'key': '...', 'secret': '...'},
///     'memory': {'driver': 'memory'},
///   },
/// );
/// ```
class StorageConfig {
  /// Disk used by `Storage()` when no disk is given.
  final String defaultDisk;

  /// Disk name to options.
  final Map<String, Map<String, dynamic>> disks;

  const StorageConfig({
    this.defaultDisk = 'local',
    this.disks = const <String, Map<String, dynamic>>{
      'local': <String, dynamic>{'driver': 'local', 'root': 'storage'},
    },
  });
}

/// Builds a `dox_storage` [DriveManager] from a [StorageConfig].
class StorageDiskFactory {
  /// [appKey] signs local URLs when a disk has no `app_key` option.
  const StorageDiskFactory({this.appKey});

  final String? appKey;

  /// A manager with one disk for each entry of [config].
  DriveManager create(StorageConfig config) {
    DriveManager manager = DriveManager(defaultDisk: config.defaultDisk);
    config.disks.forEach((String name, Map<String, dynamic> options) {
      manager.register(name, driver(name, options));
    });
    return manager;
  }

  /// One driver from its options.
  DriverContract driver(String name, Map<String, dynamic> options) {
    String? type = options['driver'] as String?;
    switch (type) {
      case 'local':
        return LocalDriver(
          LocalDriverConfig(
            root: options['root'] as String? ?? 'storage',
            urlBase: _text(options['url']),
            appKey: _text(options['app_key']) ?? _text(appKey),
            visibility: _visibility(options['visibility'], Visibility.public),
          ),
        );
      case 's3':
        return S3Driver(
          S3DriverConfig(
            bucket: options['bucket'] as String,
            region: options['region'] as String? ?? 'us-east-1',
            accessKeyId: options['key'] as String,
            secretAccessKey: options['secret'] as String,
            sessionToken: _text(options['token']),
            endpoint: _text(options['endpoint']),
            forcePathStyle: options['path_style'] as bool? ?? false,
            urlBase: _text(options['url']),
            visibility: _visibility(options['visibility'], Visibility.private),
            supportsAcl: options['acl'] as bool? ?? true,
            supportsBatchDelete: options['batch_delete'] as bool? ?? true,
          ),
        );
      case 'memory':
        return MemoryDriver();
    }
    throw ArgumentError('Storage disk "$name" has unknown driver "$type"');
  }

  String? _text(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  Visibility _visibility(Object? value, Visibility fallback) {
    if (value == 'public') return Visibility.public;
    if (value == 'private') return Visibility.private;
    return fallback;
  }
}

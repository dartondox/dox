import 'package:blog/config/env.dart';
import 'package:dox_core/dox_core.dart';

/// Storage disks
/// -------------------------------
/// `Storage()` uses the default disk. `Storage().disk('local')` picks one.
/// Drivers: local, s3 (also R2, MinIO, Spaces), memory.
StorageConfig storage = StorageConfig(
  defaultDisk: env.storageDisk,
  disks: <String, Map<String, dynamic>>{
    /// files in the `storage` folder
    'local': <String, dynamic>{'driver': 'local', 'root': 'storage'},
  },
);

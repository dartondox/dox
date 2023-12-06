import 'package:dox_core/dox_core.dart';
import 'package:dox_core/storage/local_storage_driver.dart';

FileStorageConfig storage = FileStorageConfig(
  /// default storage driver
  defaultDriver: Env.get('STORAGE_DRIVER', 'local'),

  // register storage driver list
  drivers: <String, StorageDriverInterface>{
    'local': LocalStorageDriver(),
  },
);

import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/env.dart';

/// The disks of `Storage()`. `AppStorageService` uses them.
StorageConfig storageConfig = StorageConfig(
  defaultDisk: env.storageDisk,
  disks: <String, Map<String, dynamic>>{
    /// uploads go to the `storage` folder.
    /// `url` is the public address of `Storage.route('files', ...)`.
    'local': <String, dynamic>{
      'driver': 'local',
      'root': 'storage',
      'url': '${env.appUrl}/files',
    },

    /// the front-end files (see the static files guide)
    'public': <String, dynamic>{'driver': 'local', 'root': 'public'},
  },
);

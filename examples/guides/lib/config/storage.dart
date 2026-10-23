import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

StorageConfig storage = StorageConfig(
  defaultDisk: env.storageDisk,
  disks: <String, Map<String, dynamic>>{
    /// uploads go to the `storage` folder.
    /// `url` is the public address of `Route.files('files', ...)`.
    'local': <String, dynamic>{
      'driver': 'local',
      'root': 'storage',
      'url': '${env.appUrl}/files',
    },

    /// the front-end files (see the static files guide)
    'public': <String, dynamic>{'driver': 'local', 'root': 'public'},
  },
);

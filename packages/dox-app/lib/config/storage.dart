import 'package:dox_app/config/env.dart';
import 'package:dox_core/dox_core.dart';

/// Storage disks
/// -------------------------------
/// `Storage()` uses the default disk. `Storage().disk('s3')` picks one.
/// Drivers: local, s3 (also R2, MinIO, Spaces), memory.
StorageConfig storage = StorageConfig(
  defaultDisk: env.storageDisk,
  disks: <String, Map<String, dynamic>>{
    /// files in the `storage` folder. signed URLs are served by
    /// `Route.files('files')` in routes/web.dart.
    'local': <String, dynamic>{
      'driver': 'local',
      'root': 'storage',
      'url': '${env.appUrl}/files',
    },

    /// only when AWS_BUCKET is set
    if (env.awsBucket != null)
      's3': <String, dynamic>{
        'driver': 's3',
        'bucket': env.awsBucket,
        'region': env.awsDefaultRegion,
        'key': env.awsAccessKeyId,
        'secret': env.awsSecretAccessKey,
        'endpoint': env.awsEndpoint,
      },
  },
);

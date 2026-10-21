import 'package:dox_core/dox_core.dart';

/// Storage disks
/// -------------------------------
/// `Storage()` uses the default disk. `Storage().disk('s3')` picks one.
/// Drivers: local, s3 (also R2, MinIO, Spaces), memory.
StorageConfig storage = StorageConfig(
  defaultDisk: Env.get('STORAGE_DISK', 'local'),
  disks: <String, Map<String, dynamic>>{
    /// files in the `storage` folder. signed URLs are served by
    /// `Route.files('files')` in routes/web.dart.
    'local': <String, dynamic>{
      'driver': 'local',
      'root': 'storage',
      'url': '${Env.get('APP_URL', 'http://localhost:3000')}/files',
    },

    /// only when AWS_BUCKET is set
    if (Env.get<String?>('AWS_BUCKET') != null)
      's3': <String, dynamic>{
        'driver': 's3',
        'bucket': Env.get('AWS_BUCKET'),
        'region': Env.get('AWS_DEFAULT_REGION', 'us-east-1'),
        'key': Env.get('AWS_ACCESS_KEY_ID'),
        'secret': Env.get('AWS_SECRET_ACCESS_KEY'),
        'endpoint': Env.get('AWS_ENDPOINT'),
      },
  },
);

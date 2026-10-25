import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/config/storage.dart';

/// Sets the disks of `Storage()` in every isolate. Dox finds every
/// DoxService class, see lib/generated/container.g.dart.
class AppStorageService extends StorageService {
  AppStorageService() : super(storageConfig);
}

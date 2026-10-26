import 'package:blog/config/storage.dart';
import 'package:dox_storage/dox_storage.dart';

/// Storage provider
/// --------------------------
/// Sets up the storage disks from config/storage.dart.
/// If this project does not store files, delete this file
/// (Dox finds every DoxProvider class, see lib/generated/container.g.dart).
class AppStorageProvider extends StorageProvider {
  AppStorageProvider() : super(storageConfig);
}

import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_storage/dox_storage.dart';

/// Serves files of a disk for `Route.files()`.
/// Checks the signature of local signed URLs.
class StorageFileController {
  StorageFileController(this.disk, this.signed, {this.download = false});

  /// disk name, null for the default disk
  final String? disk;

  /// only signed URLs work
  final bool signed;

  /// send every file as a download (`Content-Disposition: attachment`)
  final bool download;

  /// `GET <path>/{key*}`
  Future<dynamic> serve(DoxRequest req, String key) async {
    String fileKey = Uri.decodeComponent(key);
    if (signed && !_verify(fileKey, req.uri.queryParameters)) {
      return response('invalid or expired signature')
          .statusCode(HttpStatus.forbidden);
    }
    Storage storage = Storage().disk(disk ?? Dox().config.storage.defaultDisk);
    if (download) return storage.download(fileKey);
    return storage.stream(fileKey);
  }

  bool _verify(String key, Map<String, String> query) {
    DriverContract driver = Storage().use(disk).driver;
    if (driver is! LocalDriver) return false;
    return driver.verifySignedUrl(key, query);
  }
}

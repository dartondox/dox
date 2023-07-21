import 'dart:convert';
import 'dart:io';

import 'package:dox_core/cache/cache_driver_interface.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/aes_encryptor.dart';

class FileCacheDriver implements CacheDriverInterface {
  /// tag name
  final String tag;

  /// cache folder directory
  final String folder = 'storage/cache';

  /// Store cache into file
  const FileCacheDriver({required this.tag});

  /// Dox() APP_KEY to encrypt data
  String get _secret => Dox().config.appKey;

  /// set key value into cache
  /// default duration 1 hour
  @override
  void put(String key, String value, {Duration? duration}) {
    duration ??= Duration(hours: 1);
    Map<String, dynamic> existingData = _getData();
    existingData[key] = <String, dynamic>{
      'value': value,
      'expired_at': DateTime.now().add(duration).millisecondsSinceEpoch,
    };
    _writeData(existingData);
  }

  /// set key value into cache forever
  @override
  void forever(String key, String value) {
    put(key, value, duration: Duration(days: 365 * 100));
  }

  /// remove a key from cache
  @override
  void forget(String key) {
    Map<String, dynamic> existingData = _getData();
    existingData.remove(key);
    _writeData(existingData);
  }

  /// flush all the cache
  @override
  void flush() {
    _writeData(<String, dynamic>{});
  }

  /// get value from cache
  @override
  String? get(String key) {
    Map<String, dynamic>? data = _getData()[key];

    if (data == null) {
      return null;
    }

    int expiredAt = data['expired_at'];
    int currentTime = DateTime.now().millisecondsSinceEpoch;

    if (currentTime > expiredAt) {
      return null;
    }

    return data['value'];
  }

  /// check value exist
  @override
  bool has(String key) {
    return get(key) != null ? true : false;
  }

  /// create cache file if not exist
  /// and return cache file
  File get _cacheFile {
    String fileName = base64
        .encode(utf8.encode('dox-framework-cache-$tag'))
        .replaceAll('=', '');

    File cacheFile = File('${Directory.current.path}/$folder/$fileName');

    /// get parent directory to check folder exist
    Directory directory = Directory(cacheFile.parent.path);

    /// create directory if not exist
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    /// create file if not exist
    if (!cacheFile.existsSync()) {
      cacheFile.createSync(recursive: true);
    }
    return cacheFile;
  }

  /// get data from cache file
  Map<String, dynamic> _getData() {
    String jsonData = _cacheFile.readAsStringSync().trim();
    if (jsonData.isEmpty) {
      return <String, dynamic>{};
    }
    String decodedData = AESEncryptor.decode(jsonData, _secret);
    return json.decode(decodedData);
  }

  /// write data into cache file
  void _writeData(Map<String, dynamic> data) {
    String jsonData = json.encode(data);
    String encodedData = AESEncryptor.encode(jsonData, _secret);
    _cacheFile.writeAsStringSync(encodedData);
  }
}

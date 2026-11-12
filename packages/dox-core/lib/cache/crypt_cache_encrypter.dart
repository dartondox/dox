import 'package:dox_core/dox_core.dart';

/// The default [CacheEncrypter] of a Dox app. It uses [Crypt], so the
/// `APP_KEY` of the app is the key, and `AppConfig.previousKeys` can still
/// decrypt old entries.
///
/// [encrypt] throws a `StateError` when `APP_KEY` is empty.
///
/// [Crypt] reads the config at call time, so each isolate uses its own.
class CryptCacheEncrypter implements CacheEncrypter {
  const CryptCacheEncrypter();

  @override
  String encrypt(String text) {
    if (Dox().config.appKey.isEmpty) {
      throw StateError('Cache encryption needs APP_KEY, but APP_KEY is empty');
    }
    return Crypt.encryptString(text);
  }

  @override
  String decrypt(String text) {
    return Crypt.decryptString(text);
  }
}

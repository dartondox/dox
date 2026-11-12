/// Turns cache text into secret text and back. A store with
/// `'encrypt': true` uses it. Set it as `CacheConfig(encrypter: ...)`.
///
/// Dox gives one by default. It uses the `APP_KEY` of the app.
abstract class CacheEncrypter {
  /// [text] as secret text.
  String encrypt(String text);

  /// The text of [text] made by [encrypt]. Throws when [text] was changed
  /// or made with another key. A driver treats that as a cache miss.
  String decrypt(String text);
}

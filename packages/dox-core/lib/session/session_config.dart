import 'dart:io';

/// Settings of the session, see `SessionMiddleware`.
/// ```
/// AppConfig(
///   session: SessionConfig(driver: 'cache', store: 'redis'),
/// );
/// ```
class SessionConfig {
  const SessionConfig({
    this.driver = 'cookie',
    this.store,
    this.cookie = 'dox_session',
    this.lifetime = const Duration(hours: 2),
    this.path = '/',
    this.domain,
    this.httpOnly = true,
    this.secure,
    this.sameSite = SameSite.lax,
  });

  /// Where the data lives:
  /// - `cookie`: all data in the cookie, encrypted with AES-GCM and the
  ///   app key. No server storage. The cookie can hold about 4 KB.
  /// - `cache`: only a random session id in the (encrypted) cookie. The
  ///   data lives in the cache store [store].
  final String driver;

  /// The cache store name for the `cache` driver, like `redis`, `memory`
  /// or `file`. null uses the default store of `AppConfig.cache`.
  final String? store;

  /// The name of the session cookie.
  final String cookie;

  /// How long a session lives after its last change.
  final Duration lifetime;

  /// `Path` of the cookie.
  final String path;

  /// `Domain` of the cookie. null: only the host that set it.
  final String? domain;

  /// Page scripts can not read the cookie. Keep it true.
  final bool httpOnly;

  /// null: `Secure` when the request came over https. Set true or false
  /// to choose yourself.
  final bool? secure;

  /// `SameSite` of the cookie. `lax` stops most cross site requests.
  final SameSite? sameSite;
}

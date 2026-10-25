import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/path_pattern.dart';

/// Gives each request a session (`req.session`) and saves it after the
/// controller. Settings come from `AppConfig.session`.
/// ```
/// AppConfig(
///   globalMiddleware: <dynamic>[SessionMiddleware(), CsrfMiddleware()],
/// );
/// ```
/// With the `cookie` driver the data is read from the cookie on first
/// use. With the `cache` driver the store is read before the controller,
/// but only when the request has a session cookie.
/// The cookie is sent only when the session changed.
class SessionMiddleware implements IDoxNextMiddleware {
  /// [config] wins over `AppConfig.session`.
  const SessionMiddleware([this._config]);

  final SessionConfig? _config;

  /// cookie limit of the browsers, name and value together
  static const int maxCookieSize = 4096;

  static const String _prefix = 'session:';

  static final Expando<DoxRequest> _requests = Expando<DoxRequest>();

  /// The request of [req] when it runs this middleware, else null.
  /// The `ExceptionHandler` uses it to redirect back with errors.
  static DoxRequest? requestOf(HttpRequest req) => _requests[req];

  SessionConfig get config => _config ?? Dox().config.session;

  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    SessionConfig config = this.config;
    Session session = await _start(req, config);
    req.session = session;
    _requests[req.httpRequest] = req;
    DoxResponse res = await next();
    await _save(session, res, config);
    return res;
  }

  Future<Session> _start(DoxRequest req, SessionConfig config) async {
    String? value = req.cookie(config.cookie);
    if (config.driver == 'cookie') {
      return Session(read: value == null ? null : () => _decode(value));
    }
    _checkDriver(config);
    if (value == null) return Session();
    Object? stored = await _store(config).get('$_prefix$value');
    if (stored == null) return Session();
    return Session(id: value, read: () => stored);
  }

  Future<void> _save(
    Session session,
    DoxResponse res,
    SessionConfig config,
  ) async {
    Map<String, dynamic>? payload = session.toStore(config.lifetime);
    if (payload == null) return;
    String value;
    if (config.driver == 'cookie') {
      value = jsonEncode(payload);
      // AES-GCM adds a 12 byte nonce and a 16 byte tag, then base64
      int size =
          config.cookie.length + 1 + (utf8.encode(value).length + 30) ~/ 3 * 4;
      if (size > maxCookieSize) {
        throw StateError(
          'The session is too big for the cookie driver ($size bytes, max '
          '$maxCookieSize). Store less in the session, or use '
          "SessionConfig(driver: 'cache').",
        );
      }
    } else {
      CacheStore store = _store(config);
      String? previous = session.previousId;
      if (previous != null) await store.forget('$_prefix$previous');
      String id = session.id ??= Session.newId();
      await store.put('$_prefix$id', payload, config.lifetime);
      value = id;
    }
    res.cookie(
      DoxCookie(
        config.cookie,
        value,
        maxAge: config.lifetime,
        path: config.path,
        domain: config.domain,
        httpOnly: config.httpOnly,
        secure: config.secure,
        sameSite: config.sameSite,
      ),
    );
  }

  static Object? _decode(String value) {
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }

  static CacheStore _store(SessionConfig config) {
    return Dox().cache.store(config.store);
  }

  static void _checkDriver(SessionConfig config) {
    if (config.driver != 'cache') {
      throw StateError(
        "Session driver '${config.driver}' is not known. "
        "Use 'cookie' or 'cache'.",
      );
    }
  }
}

/// Stops cross site request forgery (CSRF).
///
/// A POST, PUT, PATCH or DELETE request must send the CSRF token of the
/// session, in the `_token` body field or the `X-CSRF-TOKEN` or
/// `X-XSRF-TOKEN` header. Else Dox answers 419.
///
/// It also sets the `XSRF-TOKEN` cookie. Page scripts can read it.
/// axios and Inertia send it back in `X-XSRF-TOKEN` for you.
/// Put it after [SessionMiddleware].
/// ```
/// CsrfMiddleware(except: <String>['/api/*', '/webhooks/stripe']);
/// ```
class CsrfMiddleware implements IDoxNextMiddleware {
  const CsrfMiddleware({this.except = const <String>[]});

  /// Paths with no check. A `*` at the end matches the rest of the path.
  final List<String> except;

  /// the name of the cookie that page scripts read
  static const String cookieName = 'XSRF-TOKEN';

  @override
  Future<DoxResponse> handle(DoxRequest req, Next next) async {
    if (_excluded(req.uri.path)) return next();
    Session session = req.session;
    String method = req.httpRequest.method;
    if (method != 'GET' &&
        method != 'HEAD' &&
        method != 'OPTIONS' &&
        !_same(session.token, _given(req))) {
      throw TokenMismatchException();
    }
    DoxResponse res = await next();
    // read it after the controller: regenerate() makes a new one
    String token = session.token;
    if (req.cookie(cookieName, decrypt: false) != token) {
      SessionConfig config = Dox().config.session;
      res.cookie(
        DoxCookie(
          cookieName,
          token,
          encrypt: false,
          httpOnly: false,
          maxAge: config.lifetime,
          path: config.path,
          domain: config.domain,
          secure: config.secure,
          sameSite: config.sameSite,
        ),
      );
    }
    return res;
  }

  bool _excluded(String path) => PathPattern.any(except, path);

  static String? _given(DoxRequest req) {
    Object? field = req.input('_token');
    if (field is String) return field;
    return req.header('X-CSRF-TOKEN') ?? req.header('X-XSRF-TOKEN');
  }

  /// compare in constant time, so the time does not leak the token
  static bool _same(String token, String? given) {
    if (given == null || given.length != token.length) return false;
    int diff = 0;
    for (int i = 0; i < token.length; i++) {
      diff |= token.codeUnitAt(i) ^ given.codeUnitAt(i);
    }
    return diff == 0;
  }
}

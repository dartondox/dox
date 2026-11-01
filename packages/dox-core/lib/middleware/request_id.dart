import 'dart:math';

import 'package:dox_core/dox_core.dart';

/// Gives each request an id. It is sent back in the `X-Request-Id`
/// header and can be read as `req.requestId`. `LogMiddleware` lines and
/// the error reports of `ExceptionHandler` show it.
///
/// ```
/// AppConfig(
///   globalMiddleware: <dynamic>[
///     const RequestId(),
///     LogMiddleware(enabled: true),
///   ],
/// );
/// ```
///
/// When the client (or a proxy) sends an `X-Request-Id` that looks safe
/// (1 to 128 characters of `A-Z a-z 0-9 . _ -`), Dox keeps it. Else Dox
/// makes a new one: 32 hex characters. Set [trustClient] to false to
/// always make a new one.
class RequestId implements IDoxMiddleware {
  const RequestId({this.trustClient = true});

  /// keep a safe `X-Request-Id` from the client
  final bool trustClient;

  /// the header name
  static const String header = 'X-Request-Id';

  static final RegExp _safe = RegExp(r'^[A-Za-z0-9._-]{1,128}$');

  /// not crypto: the id only has to be unique, not secret
  static final Random _random = Random();

  @override
  IDoxRequest handle(IDoxRequest req) {
    String? id = trustClient ? req.header(header) : null;
    if (id == null || !_safe.hasMatch(id)) id = make();
    if (req is DoxRequest) req.requestId = id;
    req.httpRequest.response.headers.set(header, id);
    return req;
  }

  /// A new random id: 32 hex characters (128 bits).
  static String make() {
    StringBuffer out = StringBuffer();
    for (int i = 0; i < 4; i++) {
      out.write(_random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'));
    }
    return out.toString();
  }
}

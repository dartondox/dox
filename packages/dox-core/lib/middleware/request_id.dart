import 'dart:math';
import 'dart:typed_data';

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

  /// [header] in lower case, so no lower case copy is made per request
  static const String _name = 'x-request-id';

  static const String _hex = '0123456789abcdef';

  static final RegExp _safe = RegExp(r'^[A-Za-z0-9._-]{1,128}$');

  /// not crypto: the id only has to be unique, not secret
  static final Random _random = Random();

  @override
  IDoxRequest handle(IDoxRequest req) {
    String? id = trustClient ? req.header(_name) : null;
    if (id == null || !_safe.hasMatch(id)) id = make();
    if (req is DoxRequest) req.requestId = id;
    req.httpRequest.response.headers.set(_name, id);
    return req;
  }

  /// A new random id: 32 hex characters (128 bits).
  static String make() {
    Uint8List out = Uint8List(32);
    for (int i = 0; i < 32; i += 8) {
      int value = _random.nextInt(1 << 32);
      for (int k = i + 7; k >= i; k--) {
        out[k] = _hex.codeUnitAt(value & 0xF);
        value >>= 4;
      }
    }
    return String.fromCharCodes(out);
  }
}

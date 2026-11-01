import 'dart:convert';

import 'package:crypto/crypto.dart' show Hmac, sha256;
import 'package:dox_core/dox_core.dart';

/// Answers `403 Forbidden` when the url of the request has no valid
/// `signature`, or its `expires` time is past. Make such urls with
/// `Route.signedUrl`.
///
/// ```
/// Route.get('unsubscribe/{user}', <dynamic>[
///   const ValidateSignature(),
///   userController.unsubscribe,
/// ]).name('unsubscribe');
///
/// String url = Route.signedUrl(
///   'unsubscribe',
///   params: <String, Object>{'user': 5},
///   expires: Duration(days: 7),
/// );
/// ```
///
/// Use `ValidateSignature(absolute: false)` for urls made with
/// `absolute: false`. An absolute url checks the scheme and host too, so
/// the `Host` of the request must be the host of `APP_URL` (or of the
/// `baseUrl` it was made with). Behind a proxy, keep the `Host` header
/// and add the proxy to `AppConfig.trustedProxies` for the scheme.
class ValidateSignature implements IDoxMiddleware {
  const ValidateSignature({this.absolute = true});

  /// the url was made with `absolute: true` (the default)
  final bool absolute;

  @override
  IDoxRequest handle(IDoxRequest req) {
    if (!hasValidSignature(req as DoxRequest, absolute: absolute)) {
      throw ForbiddenHttpException(message: 'Invalid signature');
    }
    return req;
  }

  /// True when [req] has a valid `signature` that has not expired.
  static bool hasValidSignature(DoxRequest req, {bool absolute = true}) {
    String? signature = req.uri.queryParameters['signature'];
    if (signature == null) return false;
    String query = req.uri.query.split('&').where(_notSignature).join('&');
    String path = req.uri.path;
    String url = query.isEmpty ? path : '$path?$query';
    if (absolute) {
      url = '${req.scheme()}://${req.header('host') ?? ''}$url';
    }
    if (!_signedBy(url, signature)) return false;
    String? expires = req.uri.queryParameters['expires'];
    if (expires == null) return true;
    int? at = int.tryParse(expires);
    return at != null && DateTime.now().millisecondsSinceEpoch ~/ 1000 <= at;
  }

  static bool _notSignature(String part) => !part.startsWith('signature=');

  /// [url] was signed with `APP_KEY`, or with one of `previousKeys`
  static bool _signedBy(String url, String signature) {
    if (Hash.equals(sign(url), signature)) return true;
    for (String old in Dox().config.previousKeys) {
      List<int> key = KeyDerivation.derive(old, KeyDerivation.signedUrl);
      if (Hash.equals(_hmac(key, url), signature)) return true;
    }
    return false;
  }

  /// The signature of [url] (hex HMAC-SHA256 with the signed url key).
  static String sign(String url) {
    return _hmac(KeyDerivation.forAppKey(KeyDerivation.signedUrl), url);
  }

  static String _hmac(List<int> key, String url) {
    return Hmac(sha256, key).convert(utf8.encode(url)).toString();
  }
}

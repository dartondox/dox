import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// Adds security headers to every answer. Each header has a safe
/// default. Give your own value to change it, or `null` to turn it off.
///
/// ```
/// AppConfig(
///   globalMiddleware: <dynamic>[
///     SecurityHeaders(frameOptions: 'SAMEORIGIN', permissionsPolicy: null),
///   ],
/// );
/// ```
///
/// `Strict-Transport-Security` is sent only on https requests. Behind a
/// proxy, add the proxy to `AppConfig.trustedProxies`, so Dox believes
/// its `X-Forwarded-Proto: https` header.
class SecurityHeaders implements IDoxMiddleware {
  const SecurityHeaders({
    this.contentTypeOptions = 'nosniff',
    this.frameOptions = 'DENY',
    this.referrerPolicy = 'strict-origin-when-cross-origin',
    this.strictTransportSecurity = 'max-age=31536000; includeSubDomains',
    this.permissionsPolicy = 'camera=(), microphone=(), geolocation=()',
    this.crossOriginOpenerPolicy = 'same-origin',
    this.contentSecurityPolicy,
    this.extra = const <String, String>{},
  });

  /// `X-Content-Type-Options`: the browser must not guess the type.
  final String? contentTypeOptions;

  /// `X-Frame-Options`: no other site can show the page in a frame.
  final String? frameOptions;

  /// `Referrer-Policy`: how much of the url goes to other sites.
  final String? referrerPolicy;

  /// `Strict-Transport-Security`: the browser uses only https from now on.
  /// Sent only when the request came in over https.
  final String? strictTransportSecurity;

  /// `Permissions-Policy`: browser features the page can not use.
  final String? permissionsPolicy;

  /// `Cross-Origin-Opener-Policy`: other sites that open this page in a
  /// window can not reach it.
  final String? crossOriginOpenerPolicy;

  /// `Content-Security-Policy`. Off by default, because a good policy
  /// depends on the pages of the app. Eg. `frame-ancestors 'none'`.
  final String? contentSecurityPolicy;

  /// more headers to add, name to value
  final Map<String, String> extra;

  @override
  IDoxRequest handle(IDoxRequest req) {
    HttpHeaders headers = req.httpRequest.response.headers;
    _set(headers, 'X-Content-Type-Options', contentTypeOptions);
    _set(headers, 'X-Frame-Options', frameOptions);
    _set(headers, 'Referrer-Policy', referrerPolicy);
    _set(headers, 'Permissions-Policy', permissionsPolicy);
    _set(headers, 'Cross-Origin-Opener-Policy', crossOriginOpenerPolicy);
    _set(headers, 'Content-Security-Policy', contentSecurityPolicy);
    if (req is DoxRequest && req.isSecure()) {
      _set(headers, 'Strict-Transport-Security', strictTransportSecurity);
    }
    for (MapEntry<String, String> header in extra.entries) {
      headers.set(header.key, header.value);
    }
    return req;
  }

  static void _set(HttpHeaders headers, String name, String? value) {
    if (value != null) headers.set(name, value);
  }
}

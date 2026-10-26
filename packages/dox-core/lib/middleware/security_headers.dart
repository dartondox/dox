import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// Adds security headers to every answer. Each header has a safe
/// default. Give your own value to change it, or `null` to turn it off.
/// `null` also removes a header that the server sends by default, like
/// `X-Frame-Options: SAMEORIGIN`.
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
    this.xssProtection = '0',
    this.extra = const <String, String?>{},
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

  /// `X-XSS-Protection`. `0` turns the old XSS filter of browsers off,
  /// like OWASP says. The filter is gone from new browsers, and in old
  /// ones it can make holes. Use [contentSecurityPolicy] instead.
  final String? xssProtection;

  /// more headers to add, name to value. A `null` value removes the
  /// header.
  final Map<String, String?> extra;

  @override
  IDoxRequest handle(IDoxRequest req) {
    HttpHeaders headers = req.httpRequest.response.headers;
    _set(headers, 'X-Content-Type-Options', contentTypeOptions);
    _set(headers, 'X-Frame-Options', frameOptions);
    _set(headers, 'Referrer-Policy', referrerPolicy);
    _set(headers, 'Permissions-Policy', permissionsPolicy);
    _set(headers, 'Cross-Origin-Opener-Policy', crossOriginOpenerPolicy);
    _set(headers, 'Content-Security-Policy', contentSecurityPolicy);
    _set(headers, 'X-XSS-Protection', xssProtection);
    if (req is DoxRequest && req.isSecure()) {
      _set(headers, 'Strict-Transport-Security', strictTransportSecurity);
    }
    for (MapEntry<String, String?> header in extra.entries) {
      _set(headers, header.key, header.value);
    }
    return req;
  }

  /// set the header, or remove it when [value] is null
  static void _set(HttpHeaders headers, String name, String? value) {
    if (value == null) {
      headers.removeAll(name);
    } else {
      headers.set(name, value);
    }
  }
}

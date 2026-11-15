---
icon: lucide/shield-check
---

# Security headers

`SecurityHeaders` is a middleware that adds safe HTTP headers to every answer.

The browser reads these headers and blocks some common attacks, like showing your page in a frame on another site.

## Setup

Put it first in `globalMiddleware`. Then an error from a later middleware, like a `419` or a `429`, also gets the headers:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    const SecurityHeaders(),
  ],
  // ...
);
```

Every answer now has these headers:

| Header | Default value | What it does |
| --- | --- | --- |
| `X-Content-Type-Options` | `nosniff` | The browser does not guess the file type. |
| `X-Frame-Options` | `DENY` | No site can show your page in a frame. |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Other sites only see your domain, not the full url. |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | The page can not use the camera, the microphone or the location. |
| `Cross-Origin-Opener-Policy` | `same-origin` | A page of another site that opens yours can not reach it. |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | The browser uses only https for one year. Sent only on https requests. |

`Content-Security-Policy` is off by default, because a good policy depends on your pages.

## Changing a header

Each header has an option. Give a new value to change it, or `null` to remove it. Use `extra` for other headers:

```dart
const SecurityHeaders(
  frameOptions: 'SAMEORIGIN', // allow frames from your own site
  permissionsPolicy: null, // do not send this header
  contentSecurityPolicy: "frame-ancestors 'none'",
  extra: <String, String>{'Cross-Origin-Resource-Policy': 'same-origin'},
)
```

| Option | Header |
| --- | --- |
| `contentTypeOptions` | `X-Content-Type-Options` |
| `frameOptions` | `X-Frame-Options` |
| `referrerPolicy` | `Referrer-Policy` |
| `permissionsPolicy` | `Permissions-Policy` |
| `crossOriginOpenerPolicy` | `Cross-Origin-Opener-Policy` |
| `strictTransportSecurity` | `Strict-Transport-Security` |
| `contentSecurityPolicy` | `Content-Security-Policy` |
| `xssProtection` | `X-XSS-Protection` (default `'0'`) |
| `extra` | any other headers, name to value. A `null` value removes that header |

## HSTS behind a proxy

Dox serves plain http, and a proxy (Caddy, nginx, a load balancer) does the https part. Dox sends `Strict-Transport-Security` only when the request came in over https. It knows this from the `X-Forwarded-Proto: https` header, but it only believes this header from a trusted proxy. So add your proxy to `AppConfig.trustedProxies`, or Dox never sends HSTS:

```dart
AppConfig(trustedProxies: <String>['127.0.0.1', '::1']);
```

See [App config](../reference/app-config.md).

## Details

- Without this middleware, the server already sends `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff` and `X-XSS-Protection: 0` on every answer. `SecurityHeaders` replaces them, and `null` also removes them.
- `X-XSS-Protection: 0` turns off the old XSS filter of browsers, because in old browsers it can make holes. Use `Content-Security-Policy` instead.
- Middleware runs only for routes that exist. So a `404` for an unknown URL and a preflight `OPTIONS` answer get only the three server headers.

## See also

- [Middleware](../the-basic/middleware.md)
- [CORS](cors.md)
- [Rate limiting](rate-limiting.md)

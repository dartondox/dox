---
icon: lucide/shield-check
---

# Security headers

`SecurityHeaders` is a middleware that adds safe HTTP headers to every answer.

The browser reads these headers and blocks some common attacks, like a frame of your page on another site.

## Setup

Put it first in `globalMiddleware`, so an error from a later middleware (like 419 or 429) also gets the headers:

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
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Other sites see only your domain, not the full URL. |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | The page can not use the camera, the microphone or the location. |
| `Cross-Origin-Opener-Policy` | `same-origin` | A page of another site that opens yours can not reach it. |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | The browser uses only https for one year. Sent only on https requests. |
| `X-XSS-Protection` | `0` | Turns off the old XSS filter of browsers. |

`Content-Security-Policy` is off by default, because a good policy depends on your pages.

A 404 for an unknown URL and a preflight OPTIONS answer get only the server headers `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff` and `X-XSS-Protection: 0`, because middleware runs only for routes.

## Changing a header

Give an option a new value to change its header, or null to remove it. Use `extra` for other headers:

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
| `xssProtection` | `X-XSS-Protection` |
| `extra` | any other headers, name to value. A null value removes that header |

## HSTS behind a proxy

Dox sends `Strict-Transport-Security` only when a trusted proxy sends `X-Forwarded-Proto: https`. Add your proxy to `AppConfig.trustedProxies`, or Dox never sends HSTS:

```dart
AppConfig(trustedProxies: <String>['127.0.0.1', '::1']);
```

See [App config](../reference/app-config.md).

## Next steps

- [Middleware](../the-basic/middleware.md): add middleware to routes.
- [CORS](cors.md): let other origins call your API.
- [Rate limiting](rate-limiting.md): stop clients that send too many requests.

---
icon: lucide/shield-check
---

# Security headers

`SecurityHeaders` is a middleware that adds safe HTTP headers to every answer.
The browser reads them and blocks some common attacks, like showing your page in a frame on another site.

## Turn it on

Put it in `globalMiddleware`:

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

`Content-Security-Policy` is off by default. A good policy depends on your pages.

Without this middleware, the server already sends three headers on every answer, also on a `404`:
`X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff` and `X-XSS-Protection: 1; mode=block`.
`SecurityHeaders` replaces the first two with its own values.

## Change or turn off a header

Each header has an option. Give a new value to change it, or `null` to turn it off.
`null` for `frameOptions` or `contentTypeOptions` keeps the server value from above (`SAMEORIGIN` and `nosniff`).

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
| `extra` | any other headers, name to value |

## HSTS behind a proxy

Dox serves plain http. The https part is done by a proxy (Caddy, nginx, a load balancer).
Dox sends `Strict-Transport-Security` only when the request came in over https.
It knows that from the `X-Forwarded-Proto: https` header, and it only believes this header from a trusted proxy.
So add your proxy to `AppConfig.trustedProxies`:

```dart
AppConfig(trustedProxies: <String>['127.0.0.1', '::1']);
```

Without it, Dox never sends HSTS. See [App config](../reference/app-config.md).

!!! note
    Middleware runs only for routes that exist. A `404` for an unknown url gets only the three server headers.
    A preflight `OPTIONS` answer gets only them too.
    Put `SecurityHeaders` first in `globalMiddleware`. Then an error from a later middleware, like a `419` or a `429`, also gets the headers.

## See also

- [Middleware](../the-basic/middleware.md)
- [CORS](cors.md)
- [Rate limiting](rate-limiting.md)

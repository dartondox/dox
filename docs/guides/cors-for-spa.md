# CORS for a browser front-end

Let a web app on another origin (`http://localhost:5173` in development, `https://my.app` in production) call your API.

## What you need

- A Dox app.
- A front-end that runs on its own origin, like Vite, Next.js or Flutter web.

## 1. Write the config

```dart title="lib/config/cors.dart"
import 'package:dox_core/dox_core.dart';

/// `enabled` is true by default, so every route sends the headers.
CORSConfig cors = CORSConfig(
  /// One origin only. A list is joined with commas, and browsers reject
  /// that value. Set CORS_ORIGIN to the real front-end URL in production.
  origin: Env.get('CORS_ORIGIN', 'http://localhost:5173'),

  methods: <String>['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],

  /// the request headers the front-end sends
  headers: <String>['Content-Type', 'Authorization'],

  /// the response headers the front-end may read
  exposeHeaders: <String>['Content-Disposition'],

  /// true only when the front-end sends cookies. Not needed for a
  /// `Authorization: Bearer` token.
  credentials: false,

  /// the browser keeps the preflight answer for 10 minutes
  maxAge: 600,
);
```

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  cors: cors,
  // ...
);
```

## 2. Set the origin per environment

```ini title=".env"
CORS_ORIGIN=http://localhost:5173
```

In staging and production, set `CORS_ORIGIN` as a real environment variable: `https://my.app`.
The origin is scheme, host and port. No path, no `/` at the end.

## 3. Choose `credentials`

| Your front-end sends | `origin` | `credentials` |
| --- | --- | --- |
| a token in `Authorization: Bearer` (see [JWT authentication](jwt-auth.md)) | your front-end URL | `false` |
| cookies (`fetch(url, {credentials: 'include'})`) | your front-end URL, never `*` | `true` |
| nothing, a public API | `'*'` | `false` |

Browsers do not send cookies when `origin` is `*`.

!!! warning "One origin only"
    `Access-Control-Allow-Origin` takes one origin or `*`.
    Dox sends the value of `origin` as it is. It does not compare it with the `Origin` header of the request.
    A list like `['https://a.com', 'https://b.com']` is joined to `https://a.com,https://b.com`. Browsers reject that.
    So set one origin per environment. For two front-ends, run two API hosts, or put a proxy in front that picks the header.

## Check it

The browser sends a preflight `OPTIONS` request before a `POST` with JSON or a custom header. Dox answers it by itself. You do not need an `OPTIONS` route.

```bash
curl -i -X OPTIONS http://localhost:3000/api/users \
  -H 'Origin: http://localhost:5173' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: Authorization'
```

```text
HTTP/1.1 204 No Content
access-control-allow-origin: http://localhost:5173
access-control-allow-methods: GET,POST,PUT,PATCH,DELETE
access-control-allow-headers: Content-Type,Authorization
access-control-expose-headers: Content-Disposition
access-control-allow-credentials: false
access-control-max-age: 600
```

A normal request gets the origin header too:

```bash
curl -i http://localhost:3000/api/ping -H 'Origin: http://localhost:5173' | grep -i access-control-allow-origin
```

```text
access-control-allow-origin: http://localhost:5173
```

In the browser, open the front-end and call the API with `fetch`. The console shows no CORS error.

## When it still fails

| The console says | The fix |
| --- | --- |
| `No 'Access-Control-Allow-Origin' header` | `CORS_ORIGIN` does not match the page origin exactly. Check `http` or `https`, and the port. |
| `The value of ... header is 'a.com,b.com'` | More than one origin. Use one. |
| `Request header field x-foo is not allowed` | Add the header to `headers`. |
| `credentials mode is 'include'` with `*` | Set `origin` to the front-end URL and `credentials: true`. |

## Webhooks and server-to-server calls

CORS only matters for browsers. A webhook from Stripe or a call from another server ignores these headers.
Turn CORS off for such routes to send fewer headers:

```dart
Route.disabledCors(() {
  Route.post('/webhooks/stripe', webhookController.handle);
});
```

## See also

- [CORS](../security/cors.md) for every option
- [JWT authentication](jwt-auth.md)

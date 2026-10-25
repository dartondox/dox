# CORS for a browser front-end

Let a web app on another origin (`http://localhost:5173` in development, `https://my.app` in production) call your API.

## What you need

- A Dox app.
- A front-end that runs on its own origin, like Vite, Next.js or Flutter web.

## 1. Write the config

```dart title="lib/config/cors.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

/// `enabled` is true by default, so every route sends the headers.
CORSConfig cors = CORSConfig(
  /// One origin, or a list of origins. Set CORS_ORIGIN to the real
  /// front-end URL in production.
  origin: env.corsOrigin,

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

`CORS_ORIGIN` is a new key. Add a getter for it to the `AppEnv` class:

```dart title="lib/config/env.dart"
  /// the front-end URL that may call the API
  String get corsOrigin => 'http://localhost:5173';
```

Run `dart run build_runner build` to update `env.g.dart`. Then set the value in `.env`:

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

!!! note "Two or more front-ends"
    Set `origin` to a list, like `['https://a.com', 'https://b.com']`.
    Dox compares the `Origin` header of the request with the list.
    It sends back only the origin that matches. If none matches, it sends no `Access-Control-Allow-Origin` header, and the browser blocks the call.

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
| `The value of ... header is 'a.com,b.com'` | `origin` is one text with commas. Use a `List<String>` instead. |
| `Request header field x-foo is not allowed` | Add the header to `headers`. |
| `credentials mode is 'include'` with `*` | Set `origin` to the front-end URL and `credentials: true`. |

## Webhooks and server-to-server calls

CORS only matters for browsers. A webhook from Stripe or a call from another server ignores these headers.
Turn CORS off for such routes to send fewer headers:

```dart
Route.disabledCors(() {
  Route.post<WebhookController>('/webhooks/stripe', (WebhookController c) => c.handle);
});
```

## See also

- [CORS](../security/cors.md) for every option
- [JWT authentication](jwt-auth.md)

---
icon: lucide/globe-lock
---

# CORS

CORS headers let a web page on another domain call your API.

A browser blocks a request from `https://my.app` to `https://api.my.app`, unless the API sends CORS headers. Dox adds these headers from `CORSConfig`.

## Setup

The config is in `lib/config/cors.dart`. A new app has it with `enabled: false`, so it sends no CORS headers. Set `origin` to the URL of your front end, and set `enabled: true`:

```dart title="lib/config/cors.dart"
import 'package:dox_core/dox_core.dart';

CORSConfig cors = CORSConfig(
  enabled: true,
  origin: 'https://my.app',
  methods: <String>['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  headers: <String>['Content-Type', 'Authorization'],
  exposeHeaders: <String>['Content-Disposition'],
  credentials: true,
  maxAge: 600,
);
```

Then give it to `AppConfig`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  cors: cors,
  // ...
);
```

Dox answers the preflight OPTIONS request with 204 and the CORS headers of the route. You do not add an OPTIONS route.

### Options

Each option sets one response header. An option that is not set sends no header. So with no `origin`, the browser blocks pages on other domains.

| Option | Header | Value |
| --- | --- | --- |
| `enabled` | - | true adds the headers to every route. Default: true |
| `origin` | `Access-Control-Allow-Origin` | one origin, a list of origins, or `'*'` for all |
| `methods` | `Access-Control-Allow-Methods` | a list or a text like `'GET,POST'`. `'*'` allows all |
| `headers` | `Access-Control-Allow-Headers` | a list or a text. `'*'` allows all |
| `exposeHeaders` | `Access-Control-Expose-Headers` | the response headers the page can read |
| `credentials` | `Access-Control-Allow-Credentials` | true lets the browser send cookies |
| `maxAge` | `Access-Control-Max-Age` | the seconds the browser keeps the preflight answer |

## Allowing more than one origin

Give `origin` a list. Do not put many origins in one text, because Dox sends a text as it is:

```dart
CORSConfig cors = CORSConfig(
  origin: <String>['https://my.app', 'https://admin.my.app'],
);
```

Dox sends back the request origin when it is in the list, with `Vary: Origin`. For other origins it sends no header, and the browser blocks the call.

## Sending cookies

If the front end sends cookies, set `credentials: true` and set `origin` to your real front end URLs. The browser blocks every call with cookies when the origin is `'*'`.

!!! warning
    A page on an allowed origin can send requests with the cookies of your users. List only sites that you trust.

## CORS for some routes

`enabled` is the default for all routes. Change it for a group of routes:

```dart title="lib/routes/api.dart"
// CORS headers only on these routes (use with enabled: false)
Route.enabledCors(() {
  Route.get('/public/posts', (PostController c) => c.index);
});

// no CORS headers on these routes
Route.disabledCors(() {
  Route.post('/webhooks/stripe', (WebhookController c) => c.handle);
});
```

## Next steps

- [CORS for a browser front-end](../guides/cors-for-spa.md): the setup for a React, Vue or Flutter web app.
- [CSRF protection](csrf.md): protect forms that use cookies.

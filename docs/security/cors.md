---
icon: lucide/globe-lock
---

# CORS

CORS headers let a web page on another domain call your API.

A browser blocks a request from `https://my.app` to `https://api.my.app` by default. The API must send CORS headers to allow it. Dox adds these headers from `CORSConfig`.

## Setup

The config is in `lib/config/cors.dart`. A new app has this file with `enabled: false`, so it sends no CORS headers. Set `origin` to the URL of your front end, and set `enabled: true`:

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

Then pass it to `AppConfig`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  cors: cors,
  // ...
);
```

You do not need an `OPTIONS` route. Dox answers the browser's preflight `OPTIONS` request with `204 No Content` and the CORS headers of the route the browser asks about.

## Options

Each option sets one response header. All options except `enabled` are `null` by default, and a `null` option sends no header. So with no `origin`, the browser blocks pages on other domains.

| Option | Header | Value |
| --- | --- | --- |
| `enabled` | - | `true` adds the headers to every route. Default: `true` |
| `origin` | `Access-Control-Allow-Origin` | one origin, a `List<String>` of origins, or `'*'` for all |
| `methods` | `Access-Control-Allow-Methods` | a `List<String>` or a text like `'GET,POST'`. `'*'` allows all |
| `headers` | `Access-Control-Allow-Headers` | a `List<String>` or a text. `'*'` allows all |
| `exposeHeaders` | `Access-Control-Expose-Headers` | the response headers the page may read |
| `credentials` | `Access-Control-Allow-Credentials` | `true` lets the browser send cookies |
| `maxAge` | `Access-Control-Max-Age` | how many seconds the browser keeps the preflight answer |

## Allowing more than one origin

If your API has more than one front end, give `origin` a list. Do not put many origins in one text, because a text is sent as it is:

```dart
CORSConfig cors = CORSConfig(
  origin: <String>['https://my.app', 'https://admin.my.app'],
);
```

The header accepts only one origin, so Dox checks the `Origin` header of the request. When the origin is in the list, Dox sends back that one origin. When it is not, Dox sends no header, and the browser blocks the call.

## Sending cookies

If the front end sends cookies, set `credentials: true`. Then do not use `origin: '*'`, because the browser blocks every call with cookies when the origin is `*`. Set `origin` to your real front end URL, or a list of URLs.

A page on an allowed origin can send requests with the cookies of your users, so list only sites you trust.

## CORS for some routes

`enabled` is the default for all routes. You can change it for a group of routes:

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

## Details

- For `methods`, `headers` and `exposeHeaders`, a list is joined with commas.
- With an `origin` list, Dox also sends `Vary: Origin`, so caches know the answer depends on the origin. A list with `'*'` sends `*`.

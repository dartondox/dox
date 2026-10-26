---
icon: lucide/globe-lock
---

# CORS

This page shows how to let a web page on another domain call your API.

A browser blocks a request from `https://my.app` to `https://api.my.app` by default.
The API must send CORS headers to allow it.
Dox adds these headers from `CORSConfig`.

## Set up

The config is in `lib/config/cors.dart`. Pass it to `AppConfig(cors: cors)`.
A new app has this file with `enabled: false`, so it sends no CORS headers.
Set `origin` to the URL of your front end, and set `enabled: true`.

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

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  cors: cors,
  // ...
);
```

## Options

Each option sets one response header.
An option that is `null` sends no header. All options except `enabled` are `null` by default.
So with no `origin`, Dox sends no `Access-Control-Allow-Origin` header, and the browser blocks pages on other domains.

| Option | Header | Value |
| --- | --- | --- |
| `enabled` | - | `true` adds the headers to every route. Default: `true` |
| `origin` | `Access-Control-Allow-Origin` | one origin, a `List<String>` of origins, or `'*'` for all. A text is sent as it is, so do not put many origins in one text |
| `methods` | `Access-Control-Allow-Methods` | a `List<String>` or a text like `'GET,POST'`. `'*'` allows all |
| `headers` | `Access-Control-Allow-Headers` | a `List<String>` or a text. `'*'` allows all |
| `exposeHeaders` | `Access-Control-Expose-Headers` | the response headers the page may read |
| `credentials` | `Access-Control-Allow-Credentials` | `true` lets the browser send cookies |
| `maxAge` | `Access-Control-Max-Age` | how many seconds the browser keeps the preflight answer |

For `methods`, `headers` and `exposeHeaders`, a list is joined with commas.

## More than one origin

`Access-Control-Allow-Origin` accepts only one origin or `*`.
So when `origin` is a list, Dox checks the `Origin` header of the request:

- The origin is in the list: Dox sends back that one origin.
- The origin is not in the list: Dox sends no `Access-Control-Allow-Origin` header. The browser blocks the call.
- The list has `'*'`: Dox sends `*`.

With a list, Dox also sends `Vary: Origin`. This tells caches that the answer depends on the origin.

```dart
CORSConfig cors = CORSConfig(
  origin: <String>['https://my.app', 'https://admin.my.app'],
);
```

!!! warning "`credentials` with `*`"
    Do not use `origin: '*'` with `credentials: true`.
    Dox then sends `Access-Control-Allow-Origin: *`, and the browser blocks every call that has cookies.
    When you need cookies, set `origin` to your real front-end URL, or to a list of URLs.
    A page on an allowed origin can send requests with the cookies of your users, so list only sites you trust.

## Preflight requests

Before some requests, the browser sends an `OPTIONS` request.
You do not need an `OPTIONS` route for this.
Dox answers it with `204 No Content` and the CORS headers.
It uses the CORS setting of the route that the browser asks about.

## Turn CORS on or off for some routes

`enabled` is the default for all routes.
Change it for a group of routes:

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

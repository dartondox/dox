# CORS

This page shows how to let a web page on another domain call your API.

A browser blocks a request from `https://my.app` to `https://api.my.app` by default.
The API must send CORS headers to allow it.
Dox adds these headers from `CORSConfig`.

## Set up

The config is in `lib/config/cors.dart`. Pass it to `AppConfig(cors: cors)`.

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
An option that is `null` sends no header.

| Option | Header | Value |
| --- | --- | --- |
| `enabled` | - | `true` adds the headers to every route. Default: `true` |
| `origin` | `Access-Control-Allow-Origin` | one origin, or `'*'` for all |
| `methods` | `Access-Control-Allow-Methods` | a `List<String>` or a text like `'GET,POST'`. `'*'` allows all |
| `headers` | `Access-Control-Allow-Headers` | a `List<String>` or a text. `'*'` allows all |
| `exposeHeaders` | `Access-Control-Expose-Headers` | the response headers the page may read |
| `credentials` | `Access-Control-Allow-Credentials` | `true` lets the browser send cookies |
| `maxAge` | `Access-Control-Max-Age` | how many seconds the browser keeps the preflight answer |

A list is joined with commas.
The value is sent as it is. Dox does not compare it with the `Origin` of the request.

!!! warning "One origin only"
    `Access-Control-Allow-Origin` accepts one origin or `*`.
    If you set a list like `['https://a.com', 'https://b.com']`, Dox sends `https://a.com,https://b.com`.
    Browsers reject this value.
    So set one origin, or `'*'`.

!!! warning "`credentials` with `*`"
    Browsers do not send cookies when `origin` is `'*'`.
    When you need cookies, set `origin` to your real front-end URL.

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
  Route.get('/public/posts', postController.index);
});

// no CORS headers on these routes
Route.disabledCors(() {
  Route.post('/webhooks/stripe', webhookController.handle);
});
```

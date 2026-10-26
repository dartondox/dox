---
icon: lucide/file-image
---

# Static files and SPA

Serve a folder of files, or a single page app (React, Vue, Flutter web), from the Dox app, with the right cache headers.

## What you need

- A Dox app.
- A `public` folder with the built front-end (`index.html`, `assets/...`).
- The `dox_storage` package, with its provider. See [File storage](../digging-deeper/file-storage.md#config).

## Serve a folder: one line

`Storage.route` serves every file of a storage disk. Add a `public` disk for the folder in `lib/config/storage.dart`:

```dart title="lib/config/storage.dart"
StorageConfig storageConfig = StorageConfig(
  defaultDisk: env.storageDisk,
  disks: <String, Map<String, dynamic>>{
    'local': <String, dynamic>{'driver': 'local', 'root': 'storage'},

    /// the front-end files
    'public': <String, dynamic>{'driver': 'local', 'root': 'public'},
  },
);
```

Then add the route in `register()` of `WebRouter`. `Storage` comes from `package:dox_storage/dox_storage.dart`.

```dart title="lib/routes/web.dart"
Storage.route('static', disk: 'public', signed: false); // GET /static/{key*}
```

`GET /static/app.js` sends `public/app.js`, streamed, with the right `Content-Type`. A missing file answers `404`.
The disk rejects `..` in the path, so a client can not read files outside `public`.

This is enough for a few files. It sends no `Cache-Control` header. For an SPA, go on.

## Serve an SPA

An SPA needs two things:

- `index.html` for every URL the SPA router handles, with no cache.
- The built assets with a long cache. Build tools put a hash in the file name (`app.3f9c2b.js`), so a new build has new names.

### 1. Write the controller

```dart title="lib/app/http/controllers/static.controller.dart"
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_storage/dox_storage.dart';

@Inject()
class StaticController {
  /// GET /assets/{path*}
  /// Built files have a hash in the name, so the browser may keep them
  /// for one year. The `public` disk rejects `..` in the path.
  Future<DoxResponse> asset(String path) async {
    StreamFile file = await Storage().disk('public').stream(path);
    return response(file).cache(const Duration(days: 365));
  }

  /// GET / and GET /{path*}
  /// Every other URL gets index.html, so the router of the SPA can
  /// handle it. Never cache it, so a new deploy shows at once.
  /// An unknown API URL stays a 404, it does not get the page.
  DoxResponse index(DoxRequest req) {
    if (req.uri.path.startsWith('/api/')) {
      throw NotFoundHttpException();
    }
    return response(File('public/index.html')).cache(Duration.zero);
  }
}
```

`cache(duration)` sets `Cache-Control: max-age=<seconds>`. `Duration.zero` gives `max-age=0`, so the browser asks again each time.

### 2. Add the routes

The catch-all route must come **last**. Put the API router before the web router in `AppConfig`.

```dart title="lib/routes/web.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/controllers/static.controller.dart';

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[];

  @override
  void register() {
    // the SPA: assets with a long cache, every other URL gets index.html
    Route.get('/assets/{path*}', (StaticController c) => c.asset);
    Route.get('/', (StaticController c) => c.index);
    Route.get('/{path*}', (StaticController c) => c.index);
  }
}
```

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  /// the SPA catch-all route is in WebRouter, so it must come last.
  /// Listed routers come first, in this order.
  routers: <Router>[ApiRouter(), WebRouter()],
  // ...
);
```

Keep the route for `/` as well, so the start page is always served.

### 3. Put the build in `public`

```bash
# React (Vite)
npm run build && cp -r dist/. public/

# Flutter web
flutter build web && cp -r build/web/. public/
```

Vite puts the files in `assets/`. Flutter web puts them next to `index.html`. For Flutter, change the asset route to match, or serve everything with `Storage.route` and give `index.html` the catch-all.

## Check it

```bash
curl -i http://localhost:3000/
```

```text
HTTP/1.1 200 OK
cache-control: max-age=0
content-type: text/html
```

```bash
curl -i http://localhost:3000/settings/profile   # same answer: index.html
curl -i http://localhost:3000/assets/app.js
```

```text
HTTP/1.1 200 OK
cache-control: max-age=31536000
content-type: text/javascript
```

`GET /assets/nope.js` answers `404`. `GET /assets/..%2Fpubspec.yaml` answers `404` too.
`GET /api/nothing` answers `404`, not the page.

## In production

Put the proxy in front of Dox, and let it do gzip. See [Deployment](../digging-deeper/deployment.md#https-put-a-proxy-in-front).
For a big site, serve `public` from the proxy or a CDN, and keep Dox for the API only.

## See also

- [Routing: serve storage files](../the-basic/routing.md#serve-storage-files)
- [Response: files and big responses](../the-basic/response.md#files-and-big-responses)
- [File storage](../digging-deeper/file-storage.md)

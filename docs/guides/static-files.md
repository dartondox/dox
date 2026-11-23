---
icon: lucide/file-image
---

# Static files and SPA

Serve a folder of files, or a single page app (React, Vue, Flutter web), from the Dox app, with the right cache headers.

With the front-end in the same app as your API, you have one server to run and no CORS setup.

## What you need

- A Dox app.
- A `public` folder with the built front-end (`index.html`, `assets/...`).
- For the storage disk and the controller below: the `dox_storage` package, with its provider. See [File storage](../digging-deeper/file-storage.md#configuration).

## Serve a folder: one line

`Route.staticFiles` serves the files of a folder. Add it in `register()` of `WebRouter`:

```dart title="lib/routes/web.dart"
Route.staticFiles('/', 'public');
```

Now `/app.js` sends `public/app.js`. A route wins over a file with the same path. For a `Cache-Control` header, add `maxAge`. See [Routing: serve static files](../the-basic/routing.md#serve-static-files).

For a single page app, add a [fallback route](../the-basic/routing.md#fallback-route) that sends `index.html`.

### Or serve a storage disk

`Storage.route` serves every file of a disk. First add a `public` disk for the folder:

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

Then add the route in `register()` of `WebRouter`:

```dart title="lib/routes/web.dart"
// GET /static/{key*}
Storage.route('static', disk: 'public', signed: false);
```

Now `/static/app.js` sends `public/app.js`. This route sends no `Cache-Control` header.

## Serve an SPA

A single page app (SPA) needs two things:

- `index.html` for every URL the SPA router handles, with no cache.
- The built assets with a long cache. Build tools put a hash in the file name (`app.3f9c2b.js`), so a new build has new names.

### 1. Write the controller

Write one method for the assets and one for `index.html`:

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

`cache(duration)` sets `Cache-Control: max-age=<seconds>`.

### 2. Add the routes

The catch-all route matches every URL, so it must come last. Put the API router before the web router in `AppConfig`:

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

Set the order of the routers:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  /// the SPA catch-all route is in WebRouter, so it must come last.
  /// Listed routers come first, in this order.
  routers: <Router>[ApiRouter(), WebRouter()],
  // ...
);
```

Keep the route for `/`, because `/{path*}` does not match the start page.

### 3. Put the build in `public`

Build the front-end and copy the files to `public`:

```bash
# React (Vite)
npm run build && cp -r dist/. public/

# Flutter web
flutter build web && cp -r build/web/. public/
```

Flutter web puts the files next to `index.html`, not in `assets/`. So for Flutter, change the asset route to match.

## Check it

The start page comes with no cache:

```bash
curl -i http://localhost:3000/
```

```text
HTTP/1.1 200 OK
cache-control: max-age=0
content-type: text/html
```

Any other page also gets `index.html`, and an asset gets a cache of one year:

```bash
curl -i http://localhost:3000/settings/profile   # same answer: index.html
curl -i http://localhost:3000/assets/app.js
```

```text
HTTP/1.1 200 OK
cache-control: max-age=31536000
content-type: text/javascript
```

`/assets/nope.js`, `/assets/..%2Fpubspec.yaml` and `/api/nothing` answer 404.

## In production

Put a [proxy](../digging-deeper/deployment.md#https-put-a-proxy-in-front) in front of Dox, and let it do gzip. For a big site, serve `public` from the proxy or a CDN.

## Next steps

- [Routing: serve storage files](../the-basic/routing.md#serve-storage-files): all the options of `Storage.route`.
- [Response: files and big responses](../the-basic/response.md#files-and-big-responses): send a file.
- [File storage](../digging-deeper/file-storage.md): disks and drivers.

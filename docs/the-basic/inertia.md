---
icon: lucide/app-window
---

# Inertia

Inertia lets you build a single page app with React, Vue or Svelte, and keep routes and controllers in Dox.

You do not write an API. A controller gives a page name and its props. Inertia shows the page in the browser.
The first visit gets a full HTML page. After that, links and forms get only JSON, and the page changes without a reload.

The `dox_inertia` package is the server side of Inertia. Use it with the Inertia 3 client for your front-end (`@inertiajs/react`, `@inertiajs/vue3` or `@inertiajs/svelte`, version 3) and Vite.

## Install

```bash
dart pub add dox_inertia
```

## Set up

### 1. Root view

The root view is the HTML page of the first visit. Dox puts the script and style tags in place of `@vite`, and the page in place of `@inertia`. It is plain HTML, with no template engine.

```html title="resources/views/app.html"
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>My app</title>
    @vite
  </head>
  <body>
    @inertia
  </body>
</html>
```

`@inertia` becomes the page data and the element the app renders into:

```html
<script data-page="app" type="application/json">{"component":"Home",...}</script><div id="app"></div>
```

This is the format of the Inertia 3 client. In the JSON, `<`, `>` and `&` are written as `\u003c`, `\u003e` and `\u0026`, so a prop can not end the script tag.

### 2. Config

```dart title="lib/config/inertia.dart"
import 'package:dox_inertia/dox_inertia.dart';

InertiaConfig inertiaConfig = InertiaConfig(
  /// the Vite entry files
  entryPoints: <String>['resources/js/app.jsx'],

  /// load the scripts from the Vite dev server. null in production.
  devServerUrl: 'http://localhost:5173',

  /// add the React Fast Refresh code in dev mode
  reactRefresh: true,
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `rootView` | `resources/views/app.html` | the HTML page of the first visit |
| `entryPoints` | `['resources/js/app.js']` | the Vite entry files |
| `publicPath` | `public` | the folder of public files |
| `buildDirectory` | `build` | the folder in `publicPath` where `vite build` writes its files |
| `devServerUrl` | `null` | the url of the Vite dev server, see [Vite](#vite) |
| `reactRefresh` | `false` | add the React Fast Refresh code in dev mode |
| `version` | hash of the manifest | the asset version, see [Asset version](#asset-version) |

Paths are from the project root, where the app runs.

### 3. Provider

The provider sets up Inertia in every isolate. Put it in `lib/` so the generated container finds it.

```dart title="lib/providers/inertia_provider.dart"
import 'package:dox_inertia/dox_inertia.dart';

import '../config/inertia.dart';

class AppInertiaProvider extends InertiaProvider {
  AppInertiaProvider() : super(inertiaConfig);
}
```

With no provider, Dox uses the defaults of `InertiaConfig`.

### 4. Vite

```js title="vite.config.js"
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ command }) => ({
  plugins: [react()],
  // public/ holds the Dox public files. The build goes into public/build,
  // so do not let Vite copy public/ into the build.
  publicDir: false,
  // the built files are served from /build/
  base: command === 'build' ? '/build/' : '/',
  server: { origin: 'http://localhost:5173' },
  build: {
    manifest: true,
    outDir: 'public/build',
    rollupOptions: { input: 'resources/js/app.jsx' },
  },
}))
```

```jsx title="resources/js/app.jsx"
import { createInertiaApp } from '@inertiajs/react'
import { createRoot } from 'react-dom/client'

createInertiaApp({
  resolve: (name) => {
    const pages = import.meta.glob('./Pages/**/*.jsx', { eager: true })
    return pages[`./Pages/${name}.jsx`]
  },
  setup({ el, App, props }) {
    createRoot(el).render(<App {...props} />)
  },
})
```

### 5. Serve the built files

In production the browser loads `/build/assets/...`. Add a route for them, or let your proxy (nginx, Caddy) serve `public/build`.

```dart title="lib/routes/web.dart"
Route.get('/build/{path*}', (String path) {
  if (path.contains('..')) throw NotFoundHttpException();
  // the file names have a hash, so the browser can keep them for a year
  return response(File('public/build/$path')).cache(const Duration(days: 365));
});
```

### 6. Middleware

Add three middleware to `globalMiddleware`, in this order:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    const SessionMiddleware(),
    const CsrfMiddleware(),
    HandleInertiaRequests(),
  ],
  // ...
);
```

- `SessionMiddleware` gives each request a session. Inertia uses it for validation errors and flash data.
- `CsrfMiddleware` stops cross site form posts. It sets the `XSRF-TOKEN` cookie. The Inertia client reads it and sends it back in the `X-XSRF-TOKEN` header. You do not write any code for this.
- `HandleInertiaRequests` is your `InertiaMiddleware`, see [Shared props](#shared-props). With no props to share, use `const InertiaMiddleware()`.

You can also add them to a router, in the same order, if only some routes are Inertia pages.

## Render a page

Give the request, the page name and the props. The page name is the file in `resources/js/Pages`, without the extension.

```dart title="lib/app/http/controllers/user.controller.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_inertia/dox_inertia.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class UserController {
  Future<DoxResponse> index(DoxRequest req) {
    return inertia(req, 'Users/Index', <String, dynamic>{
      'title': 'Users',
      'users': () => User().query().all(),
    });
  }
}
```

- A normal request gets the root view as HTML.
- An Inertia request (`X-Inertia: true`) gets the page as JSON, with `X-Inertia: true` and `Vary: X-Inertia`.

A prop can be a function, like `users` above. It runs only when the prop is sent. It can give a `Future`.
Props become JSON. A model or any object with `toJson()` works. A `DateTime` becomes ISO text.

## Shared props

Shared props go to every page, like the signed in user or the app name. Extend `InertiaMiddleware` and add it to `globalMiddleware` (see [Middleware](#6-middleware)).

```dart title="lib/app/http/middleware/handle_inertia_requests.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_inertia/dox_inertia.dart';

class HandleInertiaRequests extends InertiaMiddleware {
  @override
  Map<String, dynamic> share(DoxRequest req) {
    return <String, dynamic>{
      'appName': 'My app',
      'auth': () => req.auth?.toJson(),
    };
  }
}
```

A page prop with the same name wins over a shared prop. `share` can be `async`.
The page lists the names of the shared props in `sharedProps`. The client keeps them on an instant visit.
You can also share from any middleware or controller with `Inertia.share(req, {...})`.

## Partial reloads

The client can ask for some props only: `router.reload({ only: ['users'] })`. Dox reads the headers and sends only those props. Function props that are not sent do not run.

Four helpers change when a prop is sent:

```dart
return inertia(req, 'Users/Index', <String, dynamic>{
  /// only when a partial reload asks for it
  'stats': Inertia.optional(() => Stats.load()),

  /// on every request, also on a partial reload that does not ask for it
  'notices': Inertia.always(notices),

  /// not on the first visit: the page loads it right after
  'comments': Inertia.defer(() => Comment().query().all()),
  'likes': Inertia.defer(() => Like().query().count(), group: 'side'),

  /// the page adds the new items to the old ones (infinite scroll)
  'posts': Inertia.merge(posts),
});
```

| Helper | First visit | Partial reload |
| --- | --- | --- |
| plain value or function | sent | sent when asked |
| `Inertia.optional` | not sent | sent when asked |
| `Inertia.always` | sent | always sent |
| `Inertia.defer` | not sent, listed in `deferredProps` | sent when asked |
| `Inertia.merge` | sent, listed in `mergeProps` | sent when asked |

Deferred props of the same `group` load in one request. The default group is `default`.

## Forms and validation errors

A form post needs no extra code for errors. The flow is:

1. The page posts the form: `router.post('/users', data)` or `useForm`.
2. The controller validates. The validation fails.
3. Dox flashes the errors and the old input to the session, and redirects back.
4. The page loads again. It gets the errors in the `errors` prop.

```dart
Future<DoxResponse> store(DoxRequest req) async {
  await req.validateSchema(
    v.object(<String, Schema<Object?>>{
      'name': v.string().min(2),
      'email': v.string().email(),
    }),
  );
  // ... save the user
  return redirect('/users');
}
```

```jsx
const { data, setData, post, errors } = useForm({ name: '', email: '' })
// errors.email holds the message, or is undefined
```

Every page gets `errors`. It is `{}` when there are no errors. It is sent on every request, also on a partial reload.
The old input is in `req.session.old('email')`. Password fields are not kept.

With `router.post(url, data, { errorBag: 'login' })` or `form.post(url, { errorBag: 'login' })`, the client sends the `X-Inertia-Error-Bag` header. Then the errors are under the bag name: `errors.login.email`. Use it when one page has two forms.

You do not need to pass `errors` yourself. A page prop named `errors` still wins.

## Redirects

After a form, redirect with `redirect(url)` or `back(req)` from Dox.

After `PUT`, `PATCH` or `DELETE`, the browser must follow the redirect with `GET`, not with the same method. So `InertiaMiddleware` turns a `302` into `303` for these Inertia requests. You do not need to do anything.

```dart
Future<DoxResponse> update(DoxRequest req, int id) async {
  // ... save the user
  return redirect('/users'); // 303 for an Inertia PUT
}
```

To go to an outside site, or any page that is not an Inertia page, use `Inertia.location`. An Inertia request gets `409` with `X-Inertia-Location`, and the client loads the url with a full page load. Other requests get `302`.

```dart
return Inertia.location(req, 'https://checkout.example.com/pay/1');
```

## Flash data

Flash data is a short message for the next page, like "User saved". Use `Inertia.flash`. The next page gets it in `page.flash`, once.

```dart
Future<DoxResponse> store(DoxRequest req) async {
  // ... save the user
  Inertia.flash(req, 'message', 'User saved');
  return redirect('/users');
}
```

```jsx
import { usePage } from '@inertiajs/react'

const { flash } = usePage()
// flash.message is 'User saved'
```

The client also fires a `flash` event, and calls the `onFlash` callback of the visit.
`Inertia.flash` needs `SessionMiddleware`.

## Vite

In dev mode, `@vite` loads `@vite/client` and the entry files from the Vite dev server. With `reactRefresh: true` it adds the React Fast Refresh code first.

Dox is in dev mode when:

- `devServerUrl` is set, or
- the file `public/hot` exists. Its text is the dev server url. Some Vite plugins write this file while `vite` runs.

In production (no dev server), Dox reads `public/build/.vite/manifest.json`. `@vite` gives a `<link>` tag for the css of each entry and of the chunks it imports, and a `<script type="module">` tag for each entry.

Set `devServerUrl` from the env, so production does not use it:

```dart title="lib/config/inertia.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_inertia/dox_inertia.dart';

InertiaConfig inertiaConfig = InertiaConfig(
  entryPoints: <String>['resources/js/app.jsx'],
  devServerUrl: Env.get<String>('APP_ENV') == 'development'
      ? 'http://localhost:5173'
      : null,
  reactRefresh: true,
);
```

## Asset version

Each page has a version. When you deploy new assets, the version changes. A browser with the old version that makes an Inertia `GET` request gets `409` with `X-Inertia-Location`. The client then loads the whole page again, with the new assets.

The default version is a hash of the Vite manifest. Dox reads it once per isolate, so restart the server after `vite build` (a deploy does this). To set your own, use `version` in the config, eg. the git commit.

## Not included

- The Inertia 1 and 2 clients. They read the page from `<div id="app" data-page="...">`. Use the Inertia 3 client.
- Once props, scroll props (infinite scroll), `prependProps`, `deepMergeProps` and `matchPropsOn`.
- Partial reloads of nested props with dots, like `only: ['auth.user']`. Ask for the top level prop (`auth`).
- Server side rendering (SSR).
- History encryption. `encryptHistory` and `clearHistory` are always `false`.

Inertia needs [sessions](session.md) for the errors, flash data and redirects. The client sends the CSRF token by itself, see [CSRF](../security/csrf.md#axios-and-inertia).

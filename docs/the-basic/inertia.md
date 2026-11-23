---
icon: lucide/app-window
---

# Inertia

Inertia lets you build a single page app with React, Vue or Svelte, and keep routes and controllers in Dox.

A controller gives a page name and its props, and Inertia shows the page in the browser. The first visit gets a full HTML page. After that, links and forms get only JSON. The `dox_inertia` package is the server side. Use it with Vite and the Inertia 3 client (`@inertiajs/react`, `@inertiajs/vue3` or `@inertiajs/svelte`).

## Setup

Add the package with the CLI. It does steps 1 to 3 below, and prints the steps you do yourself:

```bash
dox add inertia
```

### Set it up by hand

Add the package:

```bash
dart pub add dox_inertia
```

### 1. Root view

The **root view** is the HTML page of the first visit. Dox puts the script and style tags in place of `@vite`, and the page in place of `@inertia`:

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

### 2. Config

Tell Dox where your Vite files are:

```dart title="lib/config/inertia.dart"
import 'package:dox_inertia/dox_inertia.dart';

InertiaConfig inertiaConfig = InertiaConfig(
  entryPoints: <String>['resources/js/app.jsx'],
  devServerUrl: 'http://localhost:5173',
  reactRefresh: true,
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `rootView` | `resources/views/app.html` | the HTML page of the first visit |
| `entryPoints` | `['resources/js/app.js']` | the Vite entry files |
| `publicPath` | `public` | the folder of public files |
| `buildDirectory` | `build` | the folder in `publicPath` where `vite build` writes its files |
| `devServerUrl` | null | the URL of the Vite dev server. See [Vite](#vite). |
| `reactRefresh` | false | add the React Fast Refresh code in dev mode |
| `version` | hash of the manifest | the asset version. See [Asset version](#asset-version). |
| `encryptHistory` | false | encrypt the browser history of every page. See [History encryption](#history-encryption). |
| `ssr` | null | server side rendering. See [SSR](#server-side-rendering-ssr). |

Paths are from the project root.

### 3. Provider

The provider sets up Inertia in every isolate. Put it in `lib/`:

```dart title="lib/providers/inertia_provider.dart"
import 'package:dox_inertia/dox_inertia.dart';

import '../config/inertia.dart';

class AppInertiaProvider extends InertiaProvider {
  AppInertiaProvider() : super(inertiaConfig);
}
```

With no provider, Dox uses the defaults. `Inertia.configure(config)` sets the config with no provider, and `Inertia.config` reads it.

### 4. Vite

Set up Vite so it writes a manifest into `public/build`:

```js title="vite.config.js"
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ command }) => ({
  plugins: [react()],
  // public/ holds the Dox public files, so Vite must not copy it
  publicDir: false,
  base: command === 'build' ? '/build/' : '/',
  server: { origin: 'http://localhost:5173' },
  build: {
    manifest: true,
    outDir: 'public/build',
    rollupOptions: { input: 'resources/js/app.jsx' },
  },
}))
```

Then start the Inertia app in your entry file:

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

In production the browser loads `/build/assets/...`. Add a route for them, or let your proxy serve `public/build`:

```dart title="lib/routes/web.dart"
Route.get('/build/{path*}', (String path) {
  if (path.contains('..')) throw NotFoundHttpException();
  // the file names have a hash, so the browser can keep them for a year
  return response(File('public/build/$path'))
      .cache(const Duration(days: 365));
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
);
```

- `SessionMiddleware` keeps the validation errors and the flash data. See [Session](session.md).
- `CsrfMiddleware` sets the `XSRF-TOKEN` cookie, and the Inertia client sends it back. See [CSRF](../security/csrf.md#axios-and-inertia).
- `HandleInertiaRequests` is your `InertiaMiddleware`. See [Shared props](#shared-props). With no props to share, use `const InertiaMiddleware()`.

You can also add them to a router, in the same order.

## Rendering pages

Give the request, the page name and the props. The page name is the file in `resources/js/Pages`, with no extension:

```dart title="lib/app/http/controllers/user.controller.dart"
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

A function prop, like `users`, runs only when the prop is sent. It can give a Future. Props become JSON, so a model works. `Inertia.render(req, ...)` is the same as `inertia(req, ...)`.

A Dart integer above 2^53 loses precision in JavaScript, so send such a number as a string.

### Is it an Inertia request

Check if the request came from the Inertia client:

```dart
if (Inertia.isInertia(req)) {
  // ...
}
```

## Shared props

Share props with every page, like the signed in user. Extend `InertiaMiddleware` and return them from `share`. It can be async:

```dart title="lib/app/http/middleware/handle_inertia_requests.dart"
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

A page prop with the same name wins. Share from any middleware or controller with `Inertia.share(req, {...})`, and read all shared props with `Inertia.shared(req)`.

### Global values

Share one value with the full app. Call it in the `setup()` of your provider:

```dart
@override
void setup() {
  super.setup();
  Inertia.shareGlobal('appName', 'Dox');
}
```

!!! warning
    All users get a global value. Put data of one user, like the signed in user, in `share`.

## Partial reloads

The client can ask for some props only, with `router.reload({ only: ['users'] })`. Dox then sends only those props. Ask for a top level prop, like `auth`, not `auth.user`.

These helpers change when a prop is sent:

| Helper | First visit | Partial reload |
| --- | --- | --- |
| plain value or function | sent | sent when asked |
| `Inertia.optional` | not sent | sent when asked |
| `Inertia.always` | sent | always sent |
| `Inertia.defer` | not sent, loaded right after | sent when asked |
| `Inertia.merge` | sent | sent when asked |

### Optional props

Send the prop only when a partial reload asks for it. `Inertia.lazy` is the same:

```dart
'stats': Inertia.optional(() => Stats.load()),
```

### Always props

Send the prop on every request:

```dart
'notices': Inertia.always(notices),
```

### Deferred props

Leave a slow prop out of the first visit. The page loads it right after. Props of the same `group` load in one request:

```dart
'comments': Inertia.defer(() => Comment().query().all()),
'likes': Inertia.defer(() => Like().query().count(), group: 'side'),
```

### Merging props

Add the new items to the old ones, for infinite scroll:

```dart
'posts': Inertia.merge(posts),
'feed': Inertia.defer(() => Post().query().all()).merge(),
```

## Forms and validation errors

A form post needs no extra code for errors. When validation fails, Dox flashes the errors and redirects back. The page gets them in the `errors` prop:

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

### Error bags

Keep the errors of two forms on one page apart. Pass `errorBag` in the post, and the errors are under the bag name, like `errors.login.email`:

```jsx
router.post(url, data, { errorBag: 'login' })
```

## Redirects

Redirect with `redirect(url)` or `back(req)`. After PUT, PATCH or DELETE, `InertiaMiddleware` changes a 302 into 303, so the browser follows with GET:

```dart
return redirect('/users');
```

A controller that returns nothing to an Inertia request sends the browser back, like `back(req)`.

### External redirects

Go to an outside site, or a page that is not an Inertia page, with a full page load:

```dart
return Inertia.location(req, 'https://checkout.example.com/pay/1');
```

## Flash data

Give the next page a short message, like "User saved". It needs `SessionMiddleware`:

```dart
Inertia.flash(req, 'message', 'User saved');
return redirect('/users');
```

The next page gets it in `page.flash`, one time:

```jsx
const { flash } = usePage()
// flash.message is 'User saved'
```

## Vite

In dev mode, `@vite` loads the entry files from the Vite dev server, with hot reload. In production, Dox reads `public/build/.vite/manifest.json`.

Dox is in dev mode when `devServerUrl` is set, or when `public/hot` exists. So set `devServerUrl` from the env:

```dart title="lib/config/inertia.dart"
InertiaConfig inertiaConfig = InertiaConfig(
  entryPoints: <String>['resources/js/app.jsx'],
  devServerUrl: Env.get<String>('APP_ENV') == 'development'
      ? 'http://localhost:5173'
      : null,
);
```

When `APP_ENV` is production, Dox ignores `public/hot` and prints a warning.

## Asset version

When the asset version changes, the next link click loads the full page again, with the new files. The default is a hash of the Vite manifest, read one time for each isolate. So restart the server after `vite build`.

Set your own version, for example the git commit:

```dart
InertiaConfig(version: Env.get<String>('GIT_SHA'));
```

`Inertia.version` gives the current version.

## Root view data

Give the root view a value, like the title. Write `{{ key }}` in the root view:

```html
<head>
  <meta name="csrf-token" content="{{ csrfToken }}">
  <title>{{ title }}</title>
  @vite
</head>
```

Set the values in a controller or a middleware. More calls merge the data:

```dart
Inertia.withViewData(req, <String, Object?>{'title': 'Users'});
return inertia(req, 'Users/Index');
```

- Dox fills `{{ csrfToken }}` with the CSRF token of the session.
- A key that you did not set stays as it is, so set every key of the root view.
- Each value is HTML escaped. Put it only in text or in a quoted attribute.
- Later visits do not load the root view again. So set the title in the `<Head>` component of the client too.

### Another root view for some pages

Use another HTML file for one request, like an admin area:

```dart
Inertia.setRootView(req, 'resources/views/admin.html');
return inertia(req, 'Admin/Dashboard');
```

For every page of a router, use `RootViewMiddleware`:

```dart
@override
List<dynamic> get middleware => <dynamic>[
  const RootViewMiddleware('resources/views/admin.html'),
];
```

!!! warning
    Use a fixed path. A path from the request could show any file of the server.

## History encryption

The browser keeps the props of each page in its history. After a logout, the back button can show private data. With history encryption, the browser encrypts the page data, and a cleared history can not be read. It works only on HTTPS and on localhost.

Turn it on for all pages:

```dart title="lib/config/inertia.dart"
InertiaConfig inertiaConfig = InertiaConfig(encryptHistory: true);
```

Or for one page. Pass false to turn it off for one page:

```dart
Inertia.encryptHistory(req);
return inertia(req, 'Account/Show', props);
```

Or for all pages of a router:

```dart
@override
List<dynamic> get middleware => <dynamic>[const EncryptHistoryMiddleware()];
```

Clear the history, for example at logout. It needs `SessionMiddleware`:

```dart
Inertia.clearHistory(req);
return redirect('/login');
```

## Server side rendering (SSR)

With SSR, the first visit gets the full HTML of the page, so search engines can read it. The Inertia SSR server renders it. It is a Bun or Node process next to your Dox app. Links and forms never use it.

### 1. The SSR entry file

`dox inertia:install --ssr` writes the entry file and adds a `build:ssr` script to `package.json`:

```json title="package.json"
{
  "scripts": {
    "build:ssr": "vite build && vite build --ssr resources/js/ssr.jsx --outDir bootstrap/ssr"
  }
}
```

The entry file looks like this:

```jsx title="resources/js/ssr.jsx"
import { createInertiaApp } from '@inertiajs/react'
import createServer from '@inertiajs/react/server'
import ReactDOMServer from 'react-dom/server'

createServer(
  (page) =>
    createInertiaApp({
      page,
      render: ReactDOMServer.renderToString,
      resolve: (name) => {
        const pages = import.meta.glob('./Pages/**/*.jsx', { eager: true })
        return pages[`./Pages/${name}.jsx`]
      },
      setup: ({ App, props }) => <App {...props} />,
    }),
  { host: '127.0.0.1' },
)
```

Vue and Svelte have the same `createServer`, in `@inertiajs/vue3/server` and `@inertiajs/svelte/server`. Keep `host` at 127.0.0.1, so only your own machine can reach the server.

### 2. Hydrate in the browser

Reuse the HTML from the server. Change `setup` in your app file:

```jsx title="resources/js/app.jsx"
setup({ el, App, props }) {
  if (el.hasAttribute('data-server-rendered')) {
    hydrateRoot(el, <App {...props} />)
  } else {
    createRoot(el).render(<App {...props} />)
  }
},
```

### 3. Build and run

Build the files, then start the SSR server with Bun. Add `--node` for Node:

```bash
bun run build:ssr
dox inertia:start-ssr
```

It runs `bootstrap/ssr/ssr.js` (or `ssr.mjs`) in the foreground. Run it under Docker, pm2 or systemd, and keep `node_modules` on the server.

### 4. Turn it on

Set `ssr` in the config:

```dart title="lib/config/inertia.dart"
InertiaConfig inertiaConfig = InertiaConfig(
  entryPoints: <String>['resources/js/app.jsx'],
  ssr: Env.get<String>('APP_ENV') == 'production' ? InertiaSsr() : null,
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `url` | `http://127.0.0.1:13714/render` | the render URL of the SSR server |
| `timeout` | 2 seconds | how long Dox waits for the answer |

The head tags of the page go before `</head>`. So when your pages set a title with `<Head>`, remove the title from the root view.

When the SSR server is down or slow, the visitor gets the normal page, and Dox prints one warning.

## Next steps

- [Views](views.md): server templates with no front-end framework.
- [Session](session.md): errors and flash data.
- [Static files and SPA](../guides/static-files.md): serve the built front-end files.

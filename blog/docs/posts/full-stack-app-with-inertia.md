---
date:
  created: 2026-11-12
authors:
  - dox
categories:
  - Guides
tags:
  - inertia
  - react
  - full stack
  - tutorial
slug: full-stack-app-with-inertia
---

# A full-stack app with Dox and Inertia

This post shows how to build a React app on top of Dox with Inertia, with no separate API between them.

<!-- more -->

A normal single page app needs two parts: an API on the server and a client that calls it.
You write the routes twice, the types twice and the error handling twice.

Inertia removes the API part.
A Dox controller gives a page name and its props.
Inertia shows that page in the browser, as a React, Vue or Svelte component.
The first visit gets a full HTML page. After that, links and forms get only JSON, and the page changes with no reload.

The example is a small team task list.
It lists tasks, adds a task with a form, and deletes a task.
It uses React, but Vue and Svelte work the same way.

## The steps in short

1. `dart pub add dox_inertia` and the npm packages.
2. `resources/views/app.html`: the HTML page of the first visit.
3. `lib/config/inertia.dart` and a provider.
4. `vite.config.js` and `resources/js/app.jsx`.
5. Three middleware on the web router.
6. A controller that renders pages.
7. A React page with a form.
8. Run it in dev, then build it for production.

## 1. Install

Start from a new Dox app (`dox create tasks`), then add the server package:

```bash
dart pub add dox_inertia
```

And the client packages:

```bash
npm install @inertiajs/react react react-dom
npm install -D vite @vitejs/plugin-react
```

`dox_inertia` works with the Inertia 3 client.

## 2. The root view

The root view is the HTML page of the first visit.
It is plain HTML, with no template engine.
Dox puts the script and style tags in place of `@vite`, and the page in place of `@inertia`.

```html title="resources/views/app.html"
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Tasks</title>
    @vite
  </head>
  <body>
    @inertia
  </body>
</html>
```

## 3. Config and provider

```dart title="lib/config/inertia.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_inertia/dox_inertia.dart';

InertiaConfig inertiaConfig = InertiaConfig(
  entryPoints: <String>['resources/js/app.jsx'],

  /// load the scripts from the Vite dev server, only in dev
  devServerUrl: Env.get<String>('APP_ENV') == 'development'
      ? 'http://localhost:5173'
      : null,

  /// React Fast Refresh in dev
  reactRefresh: true,
);
```

The provider sets up Inertia in every isolate.
Put it in `lib/providers/`, so the generated container finds it:

```dart title="lib/providers/inertia_provider.dart"
import 'package:dox_inertia/dox_inertia.dart';

import '../config/inertia.dart';

class AppInertiaProvider extends InertiaProvider {
  AppInertiaProvider() : super(inertiaConfig);
}
```

## 4. Vite and the client entry

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

A page name like `Tasks/Index` loads the file `resources/js/Pages/Tasks/Index.jsx`.

## 5. Middleware

Inertia needs three middleware, in this order:

- `SessionMiddleware`: keeps the validation errors and flash messages between requests.
- `CsrfMiddleware`: stops form posts from other sites. The Inertia client sends the token by itself, so you write no code for it.
- `InertiaMiddleware`: reads the Inertia headers and adds the shared props.

Add them to the web router only. Your `/api` routes stay as they are.

```dart title="lib/routes/web.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_inertia/dox_inertia.dart';
import 'package:tasks/app/http/controllers/task.controller.dart';
import 'package:tasks/app/http/middleware/handle_inertia_requests.dart';

class WebRouter extends Router {
  @override
  List<dynamic> get middleware => <dynamic>[
    const SessionMiddleware(),
    const CsrfMiddleware(),
    HandleInertiaRequests(),
  ];

  @override
  void register() {
    Route.get('/tasks', (TaskController c) => c.index);
    Route.post('/tasks', (TaskController c) => c.store);
    Route.delete('/tasks/{id}', (TaskController c) => c.destroy);
  }
}
```

Shared props go to every page, like the app name or the signed in user:

```dart title="lib/app/http/middleware/handle_inertia_requests.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_inertia/dox_inertia.dart';

class HandleInertiaRequests extends InertiaMiddleware {
  @override
  Map<String, dynamic> share(DoxRequest req) {
    return <String, dynamic>{
      'appName': 'Tasks',
      'auth': () => req.auth?.toJson(),
    };
  }
}
```

A prop can be a function. It runs only when the prop is sent.

## 6. The controller

Make a model, a migration and a DTO first:

```bash
dox make:model Task -m
dox make:dto SaveTask
```

Add a `title` column to the migration, and the same field to the model:

```dart title="lib/app/models/task/task.model.dart"
@DoxModel(table: 'tasks')
class Task extends TaskGenerator {
  @Column()
  String? title;
}
```

The DTO checks the form input:

```dart title="lib/app/dtos/save_task/save_task.dto.dart"
@Dto()
class SaveTask {
  @Trim()
  @Length(min: 3, max: 120)
  final String title;

  const SaveTask({required this.title});

  static const DtoSchema<SaveTask> schema = $SaveTaskDto;
}
```

Add `dtos: dtos` from `generated/dtos.g.dart` to `AppConfig`, so the app knows the DTOs.

Now the controller. `inertia()` takes the request, the page name and the props:

```dart title="lib/app/http/controllers/task.controller.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_inertia/dox_inertia.dart';
import 'package:tasks/app/dtos/save_task/save_task.dto.dart';
import 'package:tasks/app/models/task/task.model.dart';

@Inject()
class TaskController {
  Future<DoxResponse> index(DoxRequest req) {
    return inertia(req, 'Tasks/Index', <String, dynamic>{
      'tasks': () => Task().all(),
    });
  }

  Future<DoxResponse> store(DoxRequest req, SaveTask body) async {
    Task task = Task()..title = body.title;
    await task.save();
    Inertia.flash(req, 'message', 'Task added');
    return redirect('/tasks');
  }

  Future<DoxResponse> destroy(DoxRequest req, int id) async {
    await Task().where('id', id).delete();
    Inertia.flash(req, 'message', 'Task deleted');
    return redirect('/tasks');
  }
}
```

There is no JSON API here, and no fetch code in the client.
Three things happen for you:

- **Validation errors.** When the DTO check fails, Dox saves the errors in the session and sends the browser back. The page gets them in the `errors` prop.
- **Redirects.** After a `DELETE`, the browser must follow the redirect with `GET`. `InertiaMiddleware` changes the `302` to a `303` for you.
- **Flash messages.** `Inertia.flash` puts a message in the next page, once.

## 7. The React page

```jsx title="resources/js/Pages/Tasks/Index.jsx"
import { Head, router, useForm, usePage } from '@inertiajs/react'

export default function Index({ tasks }) {
  const { flash } = usePage()
  const { data, setData, post, processing, errors, reset } = useForm({ title: '' })

  function submit(e) {
    e.preventDefault()
    post('/tasks', { onSuccess: () => reset() })
  }

  return (
    <main>
      <Head title="Tasks" />
      {flash.message && <p className="notice">{flash.message}</p>}

      <form onSubmit={submit}>
        <input value={data.title} onChange={(e) => setData('title', e.target.value)} />
        <button disabled={processing}>Add</button>
        {errors.title && <p className="error">{errors.title}</p>}
      </form>

      <ul>
        {tasks.map((task) => (
          <li key={task.id}>
            {task.title}
            <button onClick={() => router.delete(`/tasks/${task.id}`)}>Delete</button>
          </li>
        ))}
      </ul>
    </main>
  )
}
```

The `tasks` prop is the list from the controller.
`errors.title` holds the message of the DTO rule.
Links made with `<Link>` from `@inertiajs/react` change the page with no full reload.

## 8. Run it

In dev, run two processes:

```bash
dox s
```

```bash
npx vite
```

Open `http://localhost:3000/tasks`.
Change the React page and it updates at once. Change a Dart file and the server restarts.

For production, build the client:

```bash
npx vite build
```

The files go to `public/build`. Serve them with a route in `register()`, or let nginx or Caddy serve the folder:

```dart title="lib/routes/web.dart"
// needs import 'dart:io';
Route.get('/build/{path*}', (String path) {
  if (path.contains('..')) throw NotFoundHttpException();
  // the file names have a hash, so the browser can keep them for a year
  return response(File('public/build/$path')).cache(const Duration(days: 365));
});
```

When you deploy new assets, the asset version changes.
A browser with the old version loads the whole page again, with the new files.
You do not need to do anything for this.

## More you can do

The task list is small, but the same package covers bigger apps:

- **Partial reloads.** `router.reload({ only: ['tasks'] })` asks for one prop. The other props do not run.
- **Deferred props.** `Inertia.defer(() => Stats.load())` sends a slow prop right after the first page, so the page shows sooner.
- **Infinite scroll.** `Inertia.merge(posts)` adds new items to the old list.
- **History encryption.** `Inertia.clearHistory(req)` on logout, so the back button can not show private pages.
- **Server side rendering.** Turn on `InertiaSsr()` for full HTML on the first visit, for search engines.

## What you get

- One app: Dox routes and controllers, React pages.
- No API layer, no fetch code and no client side router.
- Validation errors, flash messages and CSRF work with no extra code.
- Your `/api` routes still work for mobile apps and other clients.

Full docs: [Inertia](/latest/the-basic/inertia/)

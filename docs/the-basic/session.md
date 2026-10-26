---
icon: lucide/fingerprint
---

# Session

A session keeps data for one browser between requests. Use it for web pages: the logged in user, a cart, a "Saved" message after a form post.

An API with tokens does not need a session.

## Turn it on

Add `SessionMiddleware` to `globalMiddleware`, or to the routers or routes that need it.
Add `CsrfMiddleware` after it. See [CSRF protection](../security/csrf.md).

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    const SessionMiddleware(),
    const CsrfMiddleware(except: <String>['/api/*']),
  ],
  // ...
);
```

Now every request has `req.session`. Using `req.session` on a route without the middleware throws an error.

## Use the session

```dart
// store a value
req.session.put('cart', <int>[1, 2]);

// read a value, with a default
List<dynamic> cart = req.session.get('cart', <int>[]);

// is it there (and not null)?
bool hasCart = req.session.has('cart');

// read and remove
dynamic removed = req.session.pull('cart');

// remove one value, or all of them
req.session.forget('cart');
req.session.flush();

// all values, as a copy
Map<String, dynamic> all = req.session.all();
```

Values must be JSON types: `Map`, `List`, `String`, `num`, `bool` or `null`.

## Flash data

Flash data lives for this request and the next one. Use it for a message after a redirect.

```dart
Route.post('/posts', (DoxRequest req) async {
  // ... save the post
  req.session.flash('message', 'The post is saved');
  return redirect('/posts');
});

Route.get('/posts', (DoxRequest req) {
  String? message = req.session.get('message'); // 'The post is saved'
  // ...
});
```

"The next request" means the next request that uses the session. A request that never reads the session (like an image) does not remove it.

To keep flash data for one more request, call `req.session.reflash()`, or `req.session.keep(['message'])` for some keys only.

## Redirect back with errors

`back(req)` redirects to the page the request came from (the `Referer` header), or to `/` when there is none.
`redirect('/path')` redirects to any path.

When a form post fails validation, Dox does this for you on a route with a session:

1. It flashes the errors as `errors`, like `{'email': 'The email is not a valid email'}`.
2. It flashes the old input. Password fields (`password`, `password_confirmation`, `current_password`) and files are never kept.
3. It redirects back with `302`.

The next page reads them:

```dart
Route.get('/register', (DoxRequest req) {
  Map<String, dynamic> errors = req.session.errors; // empty when there are none
  String? email = req.session.old('email');
  // ...
});
```

A request that wants JSON still gets the normal `422` JSON answer. A request wants JSON when it has an `Accept` header with `json`, a JSON body, or `X-Requested-With: XMLHttpRequest`.
An Inertia request (it has the `X-Inertia` header) is redirected like a form post.

You can do the same by hand:

```dart
req.session.flashErrors(<String, String>{'email': 'The email is taken'}, input: req.all());
return back(req);
```

## After login and logout

```dart
// after login: a new session id and a new CSRF token, the data stays
req.session.regenerate();

// on logout: remove all data and get a new session id
req.session.invalidate();
```

Always call `regenerate()` after login. Then an id that someone saw before the login is of no use.

With the default `cookie` session driver, all session data sits in the cookie. So an old copy of the cookie still works after logout. If logout must really end old cookies, use the `cache` session driver, like `SessionConfig(driver: 'cache', store: 'redis')`.

`dox_auth` does this for you. See [Session login](../security/authentication.md#session-login-for-web-pages).

## Config

Set `session` in the app config. All options have a default.

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  session: const SessionConfig(
    driver: 'cache',
    store: 'redis',
    lifetime: Duration(hours: 2),
  ),
  // ...
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `driver` | `cookie` | `cookie` or `cache`. See below. |
| `store` | `null` | The cache store for the `cache` driver, like `redis`, `memory` or `file`. `null` uses the default store of `AppConfig.cache`. |
| `cookie` | `dox_session` | The name of the session cookie. |
| `lifetime` | 2 hours | The session ends after this long with no use. |
| `path` | `/` | `Path` of the cookie. |
| `domain` | `null` | `Domain` of the cookie. `null` means only the host that set it. |
| `httpOnly` | `true` | Page scripts can not read the cookie. |
| `secure` | `null` | `null` sets `Secure` when the request came over https. |
| `sameSite` | `SameSite.lax` | `SameSite` of the cookie (from `dart:io`). |

You can also give a config to one middleware: `SessionMiddleware(SessionConfig(...))`.

### The cookie driver

All session data is in the cookie, encrypted with AES-GCM and your `APP_KEY`. The browser can not read or change it.
There is nothing to store on the server.

A cookie can hold about 4 KB. A session that is too big gives an error. Keep the data small (an id, not a whole object), or use the `cache` driver.

### The cache driver

The cookie only has a random session id (encrypted too). The data lives in a cache store.
Use `redis` when you run more than one isolate or more than one server: then all of them see the same sessions.
A `memory` store is good for tests. It is not shared between isolates.

## When the session is read and saved

- **The cookie driver reads the session on first use.** A request that never uses `req.session` does not decrypt anything.
- **The cache driver reads the store before the controller**, but only when the request has a session cookie. A new visitor costs nothing.
- **The session is saved only when it changed.** Only then is the cookie sent. A session that is used but not changed is saved again after half of its `lifetime`, so it does not end while the user is active.

## Read the session from a package

Other packages (like an Inertia adapter) can read the same data:

```dart
if (req.hasSession) {
  Map<String, dynamic> errors = req.session.errors;
  dynamic message = req.session.get('message');
}
```

## Tests

`client.withSession()` gives a test client that keeps cookies like a browser. It also sends the `XSRF-TOKEN` cookie back in `X-XSRF-TOKEN`, so `CsrfMiddleware` lets its posts in:

```dart
DoxTestClient browser = client.withSession();
await browser.get('/cart/add?id=1');
(await browser.get('/cart')).expectJson(isNotEmpty);
```

See [Testing: keep a session](../digging-deeper/testing.md#keep-a-session-cookies-and-csrf).

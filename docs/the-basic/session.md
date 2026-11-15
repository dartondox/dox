---
icon: lucide/fingerprint
---

# Session

A session keeps data for one browser across many requests, so you can remember things like the logged in user or a shopping cart.

HTTP is stateless: each request knows nothing about the one before it. A session fixes this. Dox gives every browser a session cookie and keeps the data for that cookie between requests.

You need a session for web pages with forms and logins. An API that uses tokens does not need one.

## Setup

Add `SessionMiddleware` to `globalMiddleware`. Because session forms also need CSRF protection, add [`CsrfMiddleware`](../security/csrf.md) right after it:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    const SessionMiddleware(),
    const CsrfMiddleware(except: <String>['/api/*']),
  ],
  // ...
);
```

Now every request has `req.session`. You can also add the middleware to only some routers or routes. If a route has no session middleware, using `req.session` there throws an error.

### Configuration

Set `session` in the app config. Every option has a default, so you only set the ones you want to change:

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

The `driver` option decides where the session data is kept. Dox has two drivers:

- `cookie` (the default): all data is in the session cookie, encrypted with your `APP_KEY`. There is nothing to store on the server.
- `cache`: the cookie only holds a random session id. The data lives in a [cache store](../packages/cache.md), such as `redis`.

If you run more than one isolate or more than one server, use the `cache` driver with a shared store like `redis`, so all of them see the same sessions. See [Choosing a driver](#choosing-a-driver) for more.

## Retrieving data

Use `get` to read a value. The second argument is the default, which you get when the key is not in the session:

```dart
String? name = req.session.get('name');

List<dynamic> cart = req.session.get('cart', <int>[]);
```

### Retrieving all data

The `all` method returns a copy of all session data:

```dart
Map<String, dynamic> data = req.session.all();
```

### Checking if a value exists

The `has` method returns `true` when the key is in the session and its value is not `null`:

```dart
if (req.session.has('cart')) {
  // ...
}
```

## Storing data

Use `put` to store a value:

```dart
req.session.put('cart', <int>[1, 2]);
```

Values must be JSON types: `Map`, `List`, `String`, `num`, `bool` or `null`. This is because the session is saved as JSON.

### Retrieving and deleting a value

The `pull` method reads a value and removes it in one step:

```dart
dynamic cart = req.session.pull('cart');
```

## Flash data

Sometimes you want to keep a value only for the next request. For example, after you save a form you redirect, and the next page shows "The post is saved". Use the `flash` method for this:

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

Flash data is there for the current request and the next one. Then Dox removes it.

If you need the flash data for one more request, use `reflash`. To keep only some keys, use `keep`:

```dart
req.session.reflash();

req.session.keep(<String>['message']);
```

## Deleting data

The `forget` method removes one value. The `flush` method removes all data:

```dart
req.session.forget('cart');

req.session.flush();
```

## Regenerating the session ID

You should give the user a new session id when they log in. This stops a [session fixation](https://owasp.org/www-community/attacks/Session_fixation) attack, where someone makes a user log in with a session id the attacker already knows.

Use the `regenerate` method after login. It gives a new session id and a new CSRF token, and it keeps the data:

```dart
req.session.regenerate();
```

On logout, use `invalidate`. It removes all data and gives a new session id:

```dart
req.session.invalidate();
```

If you use [session login](../security/authentication.md#session-login-for-web-pages) from `dox_auth`, it does both for you.

## Validation errors and old input

When a form post fails [validation](validation.md) on a route with a session, Dox redirects back to the form for you. It also flashes two things, so the form can show them:

- the errors, like `{'email': 'The email is not a valid email'}`
- the old input, so the user does not have to type it again (password fields and files are never kept)

Read them on the form page:

```dart
Route.get('/register', (DoxRequest req) {
  Map<String, dynamic> errors = req.session.errors; // empty when there are none
  String? email = req.session.old('email');
  // ...
});
```

You can also do this yourself. `flashErrors` flashes the errors and the input, and `back` redirects to the page the request came from:

```dart
req.session.flashErrors(<String, String>{'email': 'The email is taken'}, input: req.all());
return back(req);
```

## Choosing a driver

### The cookie driver

The cookie driver is the default because it needs no server storage. The data is encrypted with AES-GCM and your `APP_KEY`, so the browser can not read or change it.

It has two limits:

- A cookie can hold about 4 KB. If the session gets bigger, you get an error. So keep the data small: store an id, not a whole object.
- An old copy of the cookie still works after logout, until the session `lifetime` ends. This is because the server keeps nothing it could delete.

If either limit is a problem, use the cache driver.

### The cache driver

The cache driver keeps the data in a cache store, and the cookie only holds an encrypted session id. On logout the data is deleted, so old cookies stop working.

Pick the store with the `store` option:

- `redis` shares sessions between all isolates and servers.
- `database` also shares sessions, if you have no Redis. See [Database store](../packages/cache.md#database-store).
- `memory` is good for tests. It is not shared between isolates.

```dart
SessionConfig(driver: 'cache', store: 'redis')
```

## Testing

`client.withSession()` gives a test client that keeps cookies like a browser. It also sends the CSRF token back, so `CsrfMiddleware` lets its posts in:

```dart
DoxTestClient browser = client.withSession();
await browser.get('/cart/add?id=1');
(await browser.get('/cart')).expectJson(isNotEmpty);
```

See [Testing: keep a session](../digging-deeper/testing.md#keep-a-session-cookies-and-csrf).

## Details

This section is for special cases. Most apps do not need it.

### All options

| Option | Default | What it does |
| --- | --- | --- |
| `driver` | `cookie` | `cookie` or `cache`. |
| `store` | `null` | The cache store for the `cache` driver, like `redis`, `memory` or `file`. `null` uses the default store of `AppConfig.cache`. |
| `cookie` | `dox_session` | The name of the session cookie. |
| `lifetime` | 2 hours | The session ends after this long with no use. The cookie driver keeps the save time inside the encrypted cookie, so a copied old cookie also stops working after this time. |
| `path` | `/` | `Path` of the cookie. |
| `domain` | `null` | `Domain` of the cookie. `null` means only the host that set it. |
| `httpOnly` | `true` | Page scripts can not read the cookie. |
| `secure` | `null` | `null` sets `Secure` when the request came over https. |
| `sameSite` | `SameSite.lax` | `SameSite` of the cookie (from `dart:io`). |

You can also give a config to one middleware: `SessionMiddleware(SessionConfig(...))`.

### Other cases

- `regenerate(keepToken: true)` keeps the CSRF token, so forms open in other tabs keep working. Do not use it at login.
- A request that wants JSON gets a `422` JSON answer instead of a redirect when validation fails.
- Code with no request, like a Socket.IO login, can load the session from the raw cookie value with `await SessionMiddleware().fromCookie(value)`. Changes to it are not saved.

---
icon: lucide/fingerprint
---

# Session

A session keeps data for one browser across many requests, like the logged in user or a shopping cart.

Dox gives every browser a session cookie and keeps the data for that cookie. Web pages with forms and logins need a session. An API with tokens does not.

## Setup

Add `SessionMiddleware` to `globalMiddleware`. Session forms also need [CSRF protection](../security/csrf.md), so add `CsrfMiddleware` after it:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    const SessionMiddleware(),
    const CsrfMiddleware(except: <String>['/api/*']),
  ],
);
```

Now every request has `req.session`. On a route with no session middleware, `req.session` throws.

### Configuration

Set `session` in the app config. Set only the options you want to change:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  session: const SessionConfig(
    driver: 'cache',
    store: 'redis',
    lifetime: Duration(hours: 2),
  ),
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `driver` | cookie | cookie or cache. See [Drivers](#drivers). |
| `store` | null | The cache store for the cache driver, like redis. null uses the default store. |
| `cookie` | `dox_session` | The name of the session cookie. |
| `lifetime` | 2 hours | The session ends after this time with no use. |
| `path` | `/` | The path of the cookie. |
| `domain` | null | The domain of the cookie. null means only the host that set it. |
| `httpOnly` | true | Page scripts can not read the cookie. |
| `secure` | null | null sets `Secure` when the request came over https. |
| `sameSite` | lax | The `SameSite` of the cookie. |

To give one middleware its own config, use `SessionMiddleware(SessionConfig(...))`.

### Drivers

The **driver** decides where the data is kept:

- cookie: all data is in the cookie, encrypted with your `APP_KEY`. A cookie holds about 4 KB, so store an id, not a full object. An old copy of the cookie works until the lifetime ends, also after logout.
- cache: the cookie holds only a session id, and the data is in a [cache store](../digging-deeper/cache.md). On logout the data is deleted.

For more than one server, use the cache driver with a shared store like redis or [database](../digging-deeper/cache.md#database-store). The memory store is shared by the isolates of one server only, and it is lost when the server stops.

## Retrieving data

Read a value. The second argument is the default for a missing key:

```dart
String? name = req.session.get('name');
List<dynamic> cart = req.session.get('cart', <int>[]);
```

### Retrieving all data

Get a copy of all session data:

```dart
Map<String, dynamic> data = req.session.all();
```

### Checking if a value exists

`has` gives true when the key is in the session and its value is not null:

```dart
if (req.session.has('cart')) {
  // ...
}
```

## Storing data

Store a value. It must be a JSON type: a map, a list, a string, a number, a bool or null:

```dart
req.session.put('cart', <int>[1, 2]);
```

### Retrieving and deleting a value

Read a value and remove it in one step:

```dart
dynamic cart = req.session.pull('cart');
```

## Flash data

**Flash data** stays for the current request and the next one, like a "saved" message after a redirect:

```dart
req.session.flash('message', 'The post is saved');
return redirect('/posts');
```

On the next page, `req.session.get('message')` gives the text.

### Keeping flash data

Keep all flash data for one more request, or only some keys:

```dart
req.session.reflash();
req.session.keep(<String>['message']);
```

## Deleting data

Remove one value, or all data:

```dart
req.session.forget('cart');
req.session.flush();
```

## Regenerating the session ID

Give the user a new session id at login. This stops a [session fixation](https://owasp.org/www-community/attacks/Session_fixation) attack. It also gives a new CSRF token and keeps the data:

```dart
req.session.regenerate();
```

`regenerate(keepToken: true)` keeps the CSRF token, for forms in other tabs. Do not use it at login.

At logout, remove all data and get a new id:

```dart
req.session.invalidate();
```

[Session login](../security/authentication.md#session-login-for-web-pages) from `dox_auth` does both for you.

## CSRF token

Read the CSRF token of the session. It is made on first use:

```dart
String token = req.session.token;
```

See [CSRF protection](../security/csrf.md).

## Validation errors and old input

When a form post fails [validation](validation.md), Dox redirects back to the form. It flashes the errors and the old input. Password fields and files are never kept:

```dart
Route.get('/register', (DoxRequest req) {
  Map<String, dynamic> errors = req.session.errors; // empty when none
  String? email = req.session.old('email');
  // ...
});
```

A request that wants JSON gets a 422 JSON answer instead.

### Flash errors yourself

Flash errors and input, then go back to the page the request came from:

```dart
req.session.flashErrors(<String, String>{'email': 'The email is taken'},
    input: req.all());
return back(req);
```

## Session without a request {#other-cases}

Code with no request, like a Socket.IO login, loads the session from the raw cookie value. Changes to it are not saved:

```dart
Session session = await SessionMiddleware().fromCookie(value);
session.get('auth_web');
```

## Testing

`client.withSession()` gives a test client that keeps cookies like a browser. It also sends the CSRF token:

```dart
DoxTestClient browser = client.withSession();
await browser.get('/cart/add?id=1');
(await browser.get('/cart')).expectJson(isNotEmpty);
```

See [Testing: keep a session](../digging-deeper/testing.md#keep-a-session-cookies-and-csrf).

## Next steps

- [Cache](../digging-deeper/cache.md): the stores a session can use.
- [CSRF protection](../security/csrf.md): protect forms that use the session.
- [Authentication](../security/authentication.md): session login.

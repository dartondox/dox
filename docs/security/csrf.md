---
icon: lucide/octagon-alert
---

# CSRF protection

`CsrfMiddleware` stops other sites from sending forms to your app in the name of your logged in users.

This attack is called cross site request forgery (CSRF). Another site makes the browser of your user send a form to your app. The browser sends your session cookie with it, so the request looks real.

To stop it, each session has a secret token. A request that changes data must send the token back. Another site can not read the token, so it can not send it.

## Setup

The middleware needs a session, so put it right after `SessionMiddleware`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    const SessionMiddleware(),
    const CsrfMiddleware(except: <String>['/api/*', '/webhooks/stripe']),
  ],
  // ...
);
```

Now every `POST`, `PUT`, `PATCH` and `DELETE` request must send the token. A request with no token, or a wrong one, gets a `419` with `{"code": "csrf_token_mismatch", "message": "CSRF token mismatch"}`.

`GET`, `HEAD` and `OPTIONS` requests are not checked, so never change data in a `GET` route.

## Sending the token

Dox reads the token from the `_token` field of the body, or from the `X-CSRF-TOKEN` or `X-XSRF-TOKEN` header. In your code the token is `req.session.token`.

Do not put the token in a URL, because URLs end up in logs and in the browser history. For the same reason, Dox does not read `_token` from the query string.

### HTML forms

Put the token in a hidden field. With [views](../the-basic/views.md#forms), `@csrf` writes this field for you:

```html
<form method="POST" action="/posts">
  @csrf
  ...
</form>
```

`@csrf` must be alone on its line. In the middle of a line, use `{{ csrfField() }}`, which prints the same field. If you only need the token, for example for a `<meta>` tag, use `csrfToken()`.

### axios and Inertia

Dox also sets an `XSRF-TOKEN` cookie with the token. It is not `HttpOnly`, so page scripts can read it. axios reads this cookie and sends it in the `X-XSRF-TOKEN` header by itself. Inertia uses axios, so it works with no code.

With `fetch`, read the cookie and send the header yourself:

```js
const token = document.cookie
  .split('; ')
  .find((c) => c.startsWith('XSRF-TOKEN='))
  ?.split('=')[1];

fetch('/posts', {
  method: 'POST',
  headers: { 'X-XSRF-TOKEN': token, 'Content-Type': 'application/json' },
  body: JSON.stringify({ title: 'Hi' }),
});
```

## Excluding paths

Some routes can not send the token, like webhooks that other servers call, or APIs that use tokens. List them in `except`:

```dart
const CsrfMiddleware(except: <String>['/api/*', '/webhooks/stripe']);
```

A path that ends with `*` matches everything that starts with it, so `/api/*` matches `/api/posts` and `/api/users/5`. Any other path must match exactly.

Only skip paths that do not use the session login. A webhook should check its own signature instead.

## After login

`req.session.regenerate()` also makes a new token, and Dox sends the new `XSRF-TOKEN` cookie with the same response. So after login, the client must use the new token.

## Details

- An excluded path is not checked and gets no `XSRF-TOKEN` cookie.
- `regenerate(keepToken: true)` keeps the token, so forms open in other tabs keep working. Do not use it at login, because a token from before the login would stay valid.

---
icon: lucide/octagon-alert
---

# CSRF protection

Cross site request forgery (CSRF) is an attack. Another site makes the browser of your user send a form to your app. The browser sends your session cookie with it, so the request looks real.

`CsrfMiddleware` stops it. Each session has a secret token. A request that changes data must send it back. Another site can not read the token, so it can not send it.

## Turn it on

It needs a session, so put it after `SessionMiddleware`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  globalMiddleware: <dynamic>[
    const SessionMiddleware(),
    const CsrfMiddleware(except: <String>['/api/*', '/webhooks/stripe']),
  ],
  // ...
);
```

Now every `POST`, `PUT`, `PATCH` and `DELETE` request must send the token. A request with no token, or a wrong one, gets `419` with `{"code": "csrf_token_mismatch", "message": "CSRF token mismatch"}`.

`GET`, `HEAD` and `OPTIONS` requests are not checked. Do not change data in a `GET` route.

## Send the token

Dox reads the token from one of these places:

- the `_token` field of the body
- the `X-CSRF-TOKEN` header
- the `X-XSRF-TOKEN` header

The token is `req.session.token`.

### HTML forms

Put the token in a hidden field:

```html
<form method="POST" action="/posts">
  <input type="hidden" name="_token" value="{{ token }}">
  ...
</form>
```

### axios and Inertia

Dox also sets an `XSRF-TOKEN` cookie with the token. It is not `HttpOnly`, so page scripts can read it.
axios reads this cookie and sends it in the `X-XSRF-TOKEN` header by itself. Inertia uses axios, so it works with no code.

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

## Skip some paths

Routes that other servers call (webhooks) or token based APIs can not send the token. List them in `except`:

```dart
const CsrfMiddleware(except: <String>['/api/*', '/webhooks/stripe']);
```

- A path that ends with `*` matches everything that starts with it: `/api/*` matches `/api/posts` and `/api/users/5`.
- Any other path must match exactly.

An excluded path is not checked and gets no `XSRF-TOKEN` cookie.

## After login

`req.session.regenerate()` also makes a new token. Dox sends the new `XSRF-TOKEN` cookie with the same response.

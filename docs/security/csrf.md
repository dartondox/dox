---
icon: lucide/octagon-alert
---

# CSRF protection

`CsrfMiddleware` stops other sites from sending forms to your app in the name of your logged in users.

In this attack, cross site request forgery (**CSRF**), another site makes the browser of your user send a form to your app. The browser sends the session cookie with it. To stop it, each session has a secret token, and a request that changes data must send the token back.

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

Now every POST, PUT, PATCH and DELETE request must send the token. A request with no token or a wrong token gets 419 with `{"code": "csrf_token_mismatch", "message": "CSRF token mismatch"}`.

!!! warning
    Dox does not check GET, HEAD and OPTIONS requests. Never change data in a GET route.

## Sending the token

Dox reads the token from the `_token` field of the body, or from the `X-CSRF-TOKEN` or `X-XSRF-TOKEN` header. In your code the token is `req.session.token`.

Do not put the token in a URL, because URLs go into logs and the browser history. Dox does not read `_token` from the query string.

### HTML forms

Put the token in a hidden field. In [views](../the-basic/views.md#forms), `@csrf` writes this field:

```html
<form method="POST" action="/posts">
  @csrf
  ...
</form>
```

`@csrf` must be alone on its line. In the middle of a line, use `{{ csrfField() }}`. For the token only, for example in a `<meta>` tag, use `csrfToken()`.

### axios and Inertia

Dox also sets an `XSRF-TOKEN` cookie that page scripts can read. axios sends it in the `X-XSRF-TOKEN` header, so axios and Inertia need no code.

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

List the routes that can not send the token, like webhooks and token APIs, in `except`. A path that ends with `*` matches all paths that start with it:

```dart
const CsrfMiddleware(except: <String>['/api/*', '/webhooks/stripe']);
```

!!! warning
    Exclude only paths that do not use the session login. A webhook must check its own signature.

## After login

`req.session.regenerate()` also makes a new token, and Dox sends the new `XSRF-TOKEN` cookie in the same response. After login, the client must use the new token.

`regenerate(keepToken: true)` keeps the token, so forms in other tabs keep working. Do not use it at login, because a token from before the login stays valid.

## Next steps

- [Session](../the-basic/session.md): the session that holds the token.
- [CORS](cors.md): let other origins call your API.

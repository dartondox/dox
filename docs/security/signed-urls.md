---
icon: lucide/link
---

# Signed URLs

A signed url has a `signature` in its query. Nobody can change the url without the `APP_KEY`.
Use it for links in emails, like "unsubscribe" or "download your file", where the user is not logged in.

## Make a signed url

Give the route a name and add the `ValidateSignature` middleware:

```dart title="lib/routes/web.dart"
Route.get('/unsubscribe/{user}', <dynamic>[
  const ValidateSignature(),
  (UserController c) => c.unsubscribe,
]).name('unsubscribe');
```

Then make the url with `Route.signedUrl`:

```dart
String url = Route.signedUrl(
  'unsubscribe',
  params: <String, Object>{'user': 5},
);
// https://example.com/unsubscribe/5?signature=3f9a...
```

A url with no `signature`, a wrong one, or a changed path or query gets `403 Forbidden`.

## A url that expires

Give `expires`. The url gets an `expires` query param (unix seconds), and it is signed too.
After that time the url gets `403`.

```dart
String url = Route.signedUrl(
  'download',
  params: <String, Object>{'file': 12},
  expires: Duration(hours: 1),
);
```

## Absolute and relative urls

By default the url is absolute. Dox puts `APP_URL` from the env in front, like `https://example.com`. The scheme and host are signed too.
Give `baseUrl:` to use another one.

- The `Host` of the request must be the host of `APP_URL`, with the same port.
- The scheme must match too. Behind a proxy that ends TLS, add the proxy to `AppConfig.trustedProxies`, so Dox reads `X-Forwarded-Proto: https`.

With `absolute: false`, only the path and the query are signed. Check it with `ValidateSignature(absolute: false)`:

```dart
Route.get('/files/{id}', <dynamic>[
  const ValidateSignature(absolute: false),
  (FileController c) => c.show,
]).name('files.show');

String url = Route.signedUrl(
  'files.show',
  params: <String, Object>{'id': 3},
  absolute: false,
);
// /files/3?signature=...
```

## Check in a controller

`ValidateSignature.hasValidSignature(req)` gives `true` or `false`, so you can answer in your own way:

```dart
if (!ValidateSignature.hasValidSignature(req)) {
  return redirect('/link-expired');
}
```

## How it works

- The signature is HMAC-SHA256 of the url, with a key made from `APP_KEY` (`KeyDerivation.signedUrl`).
- Dox compares it in constant time.
- After you change `APP_KEY`, urls made with an old key still work when the old key is in `AppConfig.previousKeys`.
- `signature` is a reserved query param. Any other param added to a signed url makes it invalid.

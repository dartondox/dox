---
icon: lucide/link
---

# Signed URLs

A signed URL has a `signature` in its query, so nobody can change the URL without your `APP_KEY`.

You need it for links in emails, like "unsubscribe" or "download your file", where the user is not logged in.

## Creating signed URLs

Give the route a name and add the `ValidateSignature` middleware:

```dart title="lib/routes/web.dart"
Route.get('/unsubscribe/{user}', <dynamic>[
  const ValidateSignature(),
  (UserController c) => c.unsubscribe,
]).name('unsubscribe');
```

Then make the URL with `Route.signedUrl`:

```dart
String url = Route.signedUrl(
  'unsubscribe',
  params: <String, Object>{'user': 5},
);
// https://example.com/unsubscribe/5?signature=3f9a...
```

A URL with no `signature`, a wrong one, or a changed path or query gets `403 Forbidden`.

### URLs that expire

Sometimes a link should work only for a while. Give `expires`. The URL then gets a signed `expires` query param, and after that time it gets a `403`:

```dart
String url = Route.signedUrl(
  'download',
  params: <String, Object>{'file': 12},
  expires: Duration(hours: 1),
);
```

## Relative URLs

By default the URL is absolute. Dox puts `APP_URL` in front, and the scheme and host are signed too. Give `baseUrl:` to use another one. The `Host` and the scheme of the request must match the URL it was made with: `APP_URL`, or the `baseUrl`.

If you want to sign only the path and the query, use `absolute: false`, and check it with `ValidateSignature(absolute: false)`:

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

Behind a proxy that ends TLS, add the proxy to `AppConfig.trustedProxies`, so Dox sees that the scheme is https.

## Checking in a controller

If you want to answer a bad link in your own way, use `ValidateSignature.hasValidSignature(req)`. It gives `true` or `false`:

```dart
if (!ValidateSignature.hasValidSignature(req)) {
  return redirect('/link-expired');
}
```

## Details

- The signature is HMAC-SHA256 of the URL, with a key made from `APP_KEY`. Dox compares it in constant time.
- URLs made with an old key still work when the old key is in `AppConfig.previousKeys`.
- `signature` is a reserved query param. Any other param added to a signed URL makes it invalid.
- The `Host` must match the host of `APP_URL`, with the same port.

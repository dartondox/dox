---
icon: lucide/link
---

# Signed URLs

A signed URL has a `signature` in its query, so nobody can change the URL without your `APP_KEY`.

Use it for links in emails, like "unsubscribe" or "download your file", when the user is not logged in.

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

A URL with no signature, a wrong signature, or a changed path or query gets 403. URLs made with a key in `AppConfig.previousKeys` still work.

### Adding a query

Give `query` to add query params. They are signed too. `signature` is a reserved name:

```dart
String url = Route.signedUrl(
  'unsubscribe',
  params: <String, Object>{'user': 5},
  query: <String, Object>{'list': 'news'},
);
```

### URLs that expire

Give `expires` to make a link that works only for a time. After that time it gets 403:

```dart
String url = Route.signedUrl(
  'download',
  params: <String, Object>{'file': 12},
  expires: Duration(hours: 1),
);
```

## Relative URLs

By default Dox puts `APP_URL` in front, and signs the scheme and host too. Give `baseUrl` to use another one. The scheme, host and port of the request must match it.

To sign only the path and the query, use `absolute: false`, and check it with `ValidateSignature(absolute: false)`:

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

Behind a proxy that ends TLS, add the proxy to `AppConfig.trustedProxies`, so Dox sees the https scheme.

## Checking in a controller

To answer a bad link in your own way, use `ValidateSignature.hasValidSignature(req)`:

```dart
if (!ValidateSignature.hasValidSignature(req)) {
  return redirect('/link-expired');
}
```

For a relative URL, give `absolute: false`.

## Next steps

- [File Storage](../digging-deeper/file-storage.md): signed URLs for files.
- [Encryption](encryption.md): the app key that signs the URL.

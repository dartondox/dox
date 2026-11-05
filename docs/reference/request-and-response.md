---
icon: lucide/arrow-down-up
---

# Request and response

A short list of the members of `DoxRequest`, `DoxResponse` and the response helpers.

Examples and explanations are on the [Request](../the-basic/request.md) and [Response](../the-basic/response.md) pages.

## `DoxRequest`

Source: `packages/dox-core/lib/http/request/dox_request.dart`. It implements `IDoxRequest` from `dox_annotation`.
A simple middleware (`IDoxMiddleware`) gets an `IDoxRequest`. A controller and a `next` middleware (`IDoxNextMiddleware`) get a `DoxRequest`. The members marked `IDoxRequest` are on both.

### Input

| Member | Returns | What it gives | On `IDoxRequest` |
| --- | --- | --- | --- |
| `validate<T>({Source? source})` | `Future<T>` | The request checked with the DTO `T`. Throws the `422` `ValidationException` on bad input. Throws `StateError` when `T` is not in `AppConfig.dtos`. | no |
| `validateSchema<O>(Schema<O> schema)` | `Future<O>` | Query and body checked with a fluent `dox_validation` schema. | no |
| `all()` | `Map<String, dynamic>` | Query and body together. Body wins on the same key. | yes |
| `only(List<String> keys)` | `Map<String, dynamic>` | Only these keys from `all()`. A missing key gives `null`. | yes |
| `input(String key, [dynamic defaultValue])` | `dynamic` | One value from `all()`. A dot key like `user.name` or `items.0.id` reads inside maps and lists. The default is used when the key is not there or is null. | yes |
| `except(List<String> keys)` | `Map<String, dynamic>` | All values from `all()`, without these keys. | no |
| `has(String key)` | `bool` | `true` when the key is there and its text is not empty. | yes |
| `exists(String key)` | `bool` | `true` when the key is there, with any value (also `''` or null). | no |
| `missing(String key)` | `bool` | `true` when the key is not there. | no |
| `filled(String key)` | `bool` | `true` when the key is there and not empty. Dot keys work. | no |
| `boolean(String key, [bool defaultValue = false])` | `bool` | `true` for `true`, `1`, `on` and `yes`. | no |
| `integer(String key, [int defaultValue = 0])` | `int` | The value as an `int`. The default is used when the key is not there or is not a number. | no |
| `file(String key)` | `RequestFile?` | The uploaded file, or `null` when the field is not a file. | no |
| `hasFile(String key)` | `bool` | `true` when the field holds a file or a list of files. | no |
| `add(String key, dynamic value)` | `void` | Adds a value to `all()` and `body`. | yes |
| `merge(Map<String, dynamic> values)` | `void` | Adds many values to `all()` and `body`. | yes |
| `body` | `Map<String, dynamic>` | The parsed body (JSON or form fields). Files are `RequestFile`. | no |
| `query` | `Map<String, dynamic>` | The query string. | no |
| `param` | `Map<String, dynamic>` | The route params, like `{'id': '5'}`. | no |
| `pathParams` | `Map<String, String>` | The route params as text. `null` values are left out. | no |
| `bound<T>(String param)` | `T` | The value that `Route.bind` made for this route param. Throws `StateError` when there is none. | no |
| `requestBody` | `RequestBody` | The body as it was read, for DTOs. | no |
| `isJson()` | `bool` | The content type is JSON. | yes |
| `isFormData()` | `bool` | The content type is form data (`multipart/form-data` or urlencoded). | yes |
| `toJson()` | `Map<String, dynamic>` | `all()` with files replaced by their file name. Lets `jsonEncode(req)` work. | yes |

### Headers, cookies and client

| Member | Returns | What it gives | On `IDoxRequest` |
| --- | --- | --- | --- |
| `header(String key)` | `String?` | One header. `null` when it is not there. | yes |
| `headers` | `Map<String, dynamic>` | Every header. Many values of one name are joined. | yes |
| `httpHeaders` | `HttpHeaders` | The `dart:io` headers object. | no |
| `contentType` | `ContentType?` | The parsed `Content-Type`. | yes |
| `bearerToken()` | `String?` | The token of `Authorization: Bearer <token>`, or `null`. | no |
| `cookie(String key, {bool decrypt = true})` | `String?` | One cookie. Decrypted with `appKey` unless `decrypt: false`. | yes |
| `ip()` | `String` | The client IP, or `unknown`. From `X-Forwarded-For` only behind a trusted proxy. | yes |
| `scheme()` | `String` | `http` or `https`. From `X-Forwarded-Proto` only behind a trusted proxy. | no |
| `isSecure()` | `bool` | `scheme()` is `https`. | no |
| `clientIp` | `String?` | The client IP, or `null`. | no |
| `userAgent()` | `String` | The `User-Agent` header, or `unknown`. | yes |
| `host()` | `String` | The `Host` header, or `unknown`. | yes |
| `origin()` | `String?` | The `Origin` header. | yes |
| `referer()` | `String?` | The `Referer` header. | yes |
| `locale` | `String?` | The first language of `Accept-Language`, like `th`. `null` when there is none or it is `*`. | no |
| `auth` | `IAuth?` | The auth object set by `AuthMiddleware`, or `null`. `req.auth?.id()` gives the user id. For a guest, `req.auth` is `null`. | yes |
| `expectsJson()` | `bool` | The client wants JSON: an `Accept` header with json, a JSON body, or `X-Requested-With: XMLHttpRequest`. An Inertia request is not. | no |

### Session

| Member | Returns | What it gives | On `IDoxRequest` |
| --- | --- | --- | --- |
| `session` | `Session` | The session of the request. Needs `SessionMiddleware`. Throws `StateError` without it. | no |
| `hasSession` | `bool` | `true` when the request has a session. | no |

### Route and raw request

| Member | Returns | What it gives | On `IDoxRequest` |
| --- | --- | --- | --- |
| `method` | `String` | The HTTP method in upper case. | yes |
| `uri` | `Uri` | The request URI. | yes |
| `route` | `RouteData` | The matched route. | no |
| `getRouteData()` | `RouteData` | Same as `route`. | yes |
| `path()` | `String` | The request path, like `/admin/users/5`. | no |
| `fullUrl()` | `String` | The full URL with the query string. | no |
| `pathIs(String pattern)` | `bool` | `true` when the path matches. `*` matches any text. | no |
| `routeIs(String pattern)` | `bool` | `true` when the route name matches. It is `false` for a route with no name. | no |
| `getRouteIdentifier()` | `String` | base64 of `<method>|<domain><path>`. Useful as a cache or rate limit key. | yes |
| `httpRequest` | `HttpRequest` | The `dart:io` request. Use it for raw access. | yes |

## `DoxResponse`

Source: `packages/dox-core/lib/http/response/dox_response.dart`.
Every setter returns the same `DoxResponse`, so calls chain.

| Member | Returns | What it does |
| --- | --- | --- |
| `DoxResponse(dynamic content)` | `DoxResponse` | The constructor. `content` can be a `String`, number, `Map`, `List`, a JSON serializable object, a `Stream<List<int>>`, a `File`, a `StreamFile` or a `DownloadableFile`. |
| `statusCode(int code)` | `DoxResponse` | Sets the status. Default `200`. |
| `status` | `int?` | The status set with `statusCode()`, or `null` (which means `200`). |
| `content(dynamic content)` | `DoxResponse` | Replaces the content. |
| `getContent()` | `dynamic` | The content as it was given. |
| `stream(Stream<List<int>> stream)` | `DoxResponse` | Sets a byte stream as content. |
| `contentType(ContentType type)` | `DoxResponse` | Sets `Content-Type`. A `File` without it gets the type from its extension. |
| `header(String key, dynamic value)` | `DoxResponse` | Sets one header. A second call with the same key replaces the value. `cache-control` and `Cache-Control` are one header. |
| `headers` | `Map<String, dynamic>` | The headers set so far, by name. |
| `withHeaders(Map<String, dynamic> values)` | `DoxResponse` | Adds these headers. A key replaces the header with the same name, in any case. Other headers stay. |
| `cookie(DoxCookie cookie, {bool setExpire = false})` | `DoxResponse` | Adds a `Set-Cookie` header. `setExpire: true` sends the cookie as expired, which removes it. |
| `cache(Duration duration)` | `DoxResponse` | Sets `Cache-Control: max-age=<seconds>`. |
| `process(HttpRequest request)` | `dynamic` | Internal. Writes headers, status, cookies and the body. |

## Response helpers

Top level functions in the same file. They give a `DoxResponse`.

| Function | What it does |
| --- | --- |
| `response([dynamic content])` | Same as `DoxResponse(content)`. |
| `redirect(String url, {int status = 302})` | A redirect to `url`. It sets the `Location` header. |
| `back(DoxRequest req, {String fallback = '/'})` | A `302` redirect to the `Referer` header, or to `fallback` when there is none. |

How the content is sent (`responseDataHandler` in `packages/dox-core/lib/http/http_response_handler.dart`):

| Content | Sent as |
| --- | --- |
| `null` | an empty body |
| `String` | text, as it is |
| `Map`, `List`, number, `bool`, object with `toJson()` | JSON, `Content-Type: application/json` |
| `DateTime` | its ISO 8601 text |
| `File` | streamed, with `Content-Length`, `Accept-Ranges` and one `Range` supported |
| `StreamFile` | streamed with its content type. An HTML, XML or JavaScript type is sent as a download, in a sandbox. |
| `DownloadableFile` | streamed with `Content-Disposition: attachment; filename="<name>"` |
| `Stream<List<int>>` | streamed chunk by chunk |
| `IHttpException` | its status and `toResponse()`, see [HTTP exceptions](http-exceptions.md) |
| other `Exception` or `Error` | `500` with `{"code": "server_error", "message": "Server Error"}`. When `APP_ENV` is `development` or `local`, the body is `toString()` as text. |

A plain value returned from a controller (not a `DoxResponse`) is sent the same way. It only goes through a `DoxResponse` when `AppConfig.responseHandler` is set, or when it is a `File`, `StreamFile` or `DownloadableFile`.

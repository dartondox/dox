# Request and response

A compact list of the members of `DoxRequest` and `DoxResponse`.

Examples and explanations are on the [Request](../the-basic/request.md) and [Response](../the-basic/response.md) pages.

## `DoxRequest`

Source: `packages/dox-core/lib/http/request/dox_request.dart`. It implements `IDoxRequest` from `dox_annotation`.
A middleware gets an `IDoxRequest`. A controller gets a `DoxRequest`. The members marked `IDoxRequest` are on both.

### Input

| Member | Returns | What it gives | On `IDoxRequest` |
| --- | --- | --- | --- |
| `validate<T>({Source? source})` | `Future<T>` | The request checked with the DTO `T`. Throws the `422` `ValidationException` on bad input. Throws `StateError` when `T` is not in `AppConfig.dtos`. | no |
| `validateSchema<O>(Schema<O> schema)` | `Future<O>` | Query and body checked with a fluent `dox_validation` schema. | no |
| `all()` | `Map<String, dynamic>` | Query and body together. Body wins on the same key. | yes |
| `only(List<String> keys)` | `Map<String, dynamic>` | Only these keys from `all()`. A missing key gives `null`. | yes |
| `input(String key)` | `dynamic` | One value from `all()`. | yes |
| `has(String key)` | `bool` | `true` when the key is there and its text is not empty. | yes |
| `add(String key, dynamic value)` | `void` | Adds a value to `all()` and `body`. | yes |
| `merge(Map<String, dynamic> values)` | `void` | Adds many values to `all()` and `body`. | yes |
| `body` | `Map<String, dynamic>` | The parsed body (JSON or form fields). Files are `RequestFile`. | no |
| `query` | `Map<String, dynamic>` | The query string. | no |
| `param` | `Map<String, dynamic>` | The route params, like `{'id': '5'}`. | no |
| `pathParams` | `Map<String, String>` | The route params as text. `null` values are left out. | no |
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
| `auth` | `IAuth?` | The auth object set by `AuthMiddleware`, or `null`. | yes |

### Route and raw request

| Member | Returns | What it gives | On `IDoxRequest` |
| --- | --- | --- | --- |
| `method` | `String` | The HTTP method in upper case. | yes |
| `uri` | `Uri` | The request URI. | yes |
| `route` | `RouteData` | The matched route. | no |
| `getRouteData()` | `RouteData` | Same as `route`. | yes |
| `getRouteIdentifier()` | `String` | base64 of `<method>|<domain><path>`. Useful as a cache or rate limit key. | yes |
| `httpRequest` | `HttpRequest` | The `dart:io` request. Use it for raw access. | yes |

## `DoxResponse`

Source: `packages/dox-core/lib/http/response/dox_response.dart`.
Every setter returns the same `DoxResponse`, so calls chain.

| Member | Returns | What it does |
| --- | --- | --- |
| `DoxResponse(dynamic content)` | `DoxResponse` | The constructor. `content` can be a `String`, number, `Map`, `List`, a JSON serializable object, a `Stream<List<int>>`, a `File`, a `StreamFile` or a `DownloadableFile`. |
| `response([dynamic content])` | `DoxResponse` | Top level helper. Same as `DoxResponse(content)`. |
| `statusCode(int code)` | `DoxResponse` | Sets the status. Default `200`. |
| `content(dynamic content)` | `DoxResponse` | Replaces the content. |
| `getContent()` | `dynamic` | The content as it was given. |
| `stream(Stream<List<int>> stream)` | `DoxResponse` | Sets a byte stream as content. |
| `contentType(ContentType type)` | `DoxResponse` | Sets `Content-Type`. A `File` without it gets the type from its extension. |
| `header(String key, dynamic value)` | `DoxResponse` | Adds one header. |
| `withHeaders(Map<String, dynamic> values)` | `DoxResponse` | Replaces every header set so far with this map. |
| `cookie(DoxCookie cookie, {bool setExpire = false})` | `DoxResponse` | Adds a `Set-Cookie` header. `setExpire: true` sends the cookie as expired, which removes it. |
| `cache(Duration duration)` | `DoxResponse` | Sets `Cache-Control: max-age=<seconds>`. |
| `process(HttpRequest request)` | `dynamic` | Internal. Writes headers, status, cookies and the body. |

How the content is sent (`responseDataHandler` in `packages/dox-core/lib/http/http_response_handler.dart`):

| Content | Sent as |
| --- | --- |
| `null` | an empty body |
| `String` | text, as it is |
| `Map`, `List`, number, `bool`, object with `toJson()` | JSON, `Content-Type: application/json` |
| `DateTime` | its ISO 8601 text |
| `File` | streamed, with `Content-Length`, `Accept-Ranges` and one `Range` supported |
| `StreamFile` | streamed with its content type |
| `DownloadableFile` | streamed with `Content-Disposition: attachment` |
| `Stream<List<int>>` | streamed chunk by chunk |
| `IHttpException` | its status and `toResponse()`, see [HTTP exceptions](http-exceptions.md) |
| other `Exception` or `Error` | `500` with `toString()` as text |

A plain value returned from a controller (not a `DoxResponse`) is sent the same way. It only goes through a `DoxResponse` when `AppConfig.responseHandler` is set, or when it is a `File`, `StreamFile` or `DownloadableFile`.

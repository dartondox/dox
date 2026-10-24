## Unreleased

- Security: a multipart form may be up to `maxMultipartSize` bytes (new `bind` option, default `maxBodySize`). Any other body, eg. JSON, raw or text, is limited to `maxBodySize`. Dox passes its own two limits, so a JSON body over 10 MB now gets `413` from Rust.
- Security: a body with a too big `Content-Length` and `Expect: 100-continue` gets `413` at once. Without `Expect`, Rust reads and drops the body (up to 64 MB more, no memory kept), then sends `413`, so the client sees the `413` and not a connection reset.
- Security: Rust no longer reserves memory from the client `Content-Length` (at most 64 KB up front).
- Security: new `bind` option `bodyTimeout` (default 120 seconds). It is the idle time with no body bytes: a client that sends nothing for that long gets `408`. A slow but steady upload is fine.
- Native ABI 4 (`dox_start` takes the multipart limit and the body timeout). Needs a new native library build.
- Security: response headers now refuse bad input with a `FormatException`, like `dart:io`. A header name must be a token. A header value must not hold a line break or other control byte. Before, a `\n` in a value (or a char like `\u010A`, written as its low byte) added one more header, eg. `Set-Cookie`, when an app put request input in a header. The same check now runs on `serverHeader` and on each cookie when the response closes, because `Cookie` does not check its domain.

## 3.0.0-alpha.6

- Version bump only, to match the other packages.

## 3.0.0-alpha.5

- New: `NativeHttpServer.bind(port, address: ...)` listens on one host, like `HttpServer.bind`. An `InternetAddress` or a host name. With no address it listens on all interfaces, as before. `server.address` is the real address.
- Fix: `close()` never finished when nobody called `listen()` on the server.
- Native ABI 3 (`dox_start` takes the host). Needs a new native library build. Until the next release, the build hook builds it with cargo.
- New: `close()` is graceful, like `dart:io`. The server stops taking connections at once, each open connection closes after its current answer, and the future completes when all are closed. `close(force: true)` closes every connection at once.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- `DOX_HTTP_THREAD=shared` runs one `dox-http` thread for all isolates.
  Default is still one thread per isolate, which measured faster.
- Less work per request: request headers are read one name at a time,
  answers are not copied again in Rust, one wake per answer batch.
- Native ABI 2 (new header layout in the request record). Needs a new
  native library build.

## 3.0.0-alpha.2

- First release.
- Native HTTP/1.1 server: Rust (hyper, tokio) owns the sockets and parses
  HTTP. Handlers stay in Dart.
- Implements the `dart:io` `HttpServer`, `HttpRequest` and `HttpResponse`
  API, so code written for `dart:io` works unchanged.
- One server per isolate on the same port (`SO_REUSEPORT` on Linux and macOS).
- 400 for bad requests, 431 for big headers, 413 for big bodies.
- The build hook downloads a ready-built library. No Rust needed.

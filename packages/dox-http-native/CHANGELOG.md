## 3.0.0-alpha.1

- First release.
- Native HTTP/1.1 server: Rust (hyper, tokio) owns the sockets and parses
  HTTP. Handlers stay in Dart.
- Implements the `dart:io` `HttpServer`, `HttpRequest` and `HttpResponse`
  API, so code written for `dart:io` works unchanged.
- One server per isolate on the same port (`SO_REUSEPORT` on Linux and macOS).
- 400 for bad requests, 431 for big headers, 413 for big bodies.
- The build hook downloads a ready-built library. No Rust needed.

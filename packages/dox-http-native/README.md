# dox_http_native

A fast HTTP/1.1 server for Dart. Rust ([hyper](https://hyper.rs)) owns the
sockets and parses HTTP. Your handlers stay in Dart.

It implements the `dart:io` `HttpServer`, `HttpRequest` and `HttpResponse`
API, so code written for `dart:io` works unchanged.

[Dox](https://dartondox.dev) uses it as its default server. You do not need
to add it yourself when you use Dox.

```dart
import 'dart:io';

import 'package:dox_http_native/dox_http_native.dart';

void main() async {
  NativeHttpServer server = await NativeHttpServer.bind(3000);
  server.listen((HttpRequest req) {
    req.response.write('Hello World');
    req.response.close();
  });
}
```

- No Rust needed: the build hook downloads a ready-built library
  (macOS arm64/x64, Linux x64/arm64, Windows x64).
- Use `dart run`, `dart test` or `dart build cli`. `dart compile exe` does
  not run build hooks.
- Each isolate can bind the same port (`SO_REUSEPORT` on Linux, one shared
  socket on macOS).
- Each isolate has its own `dox-http` thread. `DOX_HTTP_THREAD=shared`
  puts them all on one thread (slower on 2 cores in our tests).
- `400` for bad requests, `431` for headers over 16 KB, `413` for bodies
  over `maxBodySize`.
- Not yet: WebSocket upgrade (`detachSocket`), streaming a response while it
  is written (the body is sent on `close`).

More: [Native server](https://dartondox.dev/digging-deeper/native-server/).

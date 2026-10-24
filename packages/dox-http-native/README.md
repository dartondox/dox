# dox_http_native

Native HTTP/1.1 server for Dart. It is the default HTTP server of Dox.

[![pub package](https://img.shields.io/pub/v/dox_http_native.svg)](https://pub.dev/packages/dox_http_native)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/develop/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

You usually do not add this package. `dox_core` depends on it and uses it by default.
Add it only to use the server without Dox:

```bash
dart pub add dox_http_native
```

Dox 3.x is in alpha (`3.0.0-alpha.x`). The API can still change before the stable release.

## How it works

- Rust ([hyper](https://hyper.rs)) owns the sockets and parses HTTP/1.1.
- Your handlers stay in Dart.
- It implements the `dart:io` `HttpServer`, `HttpRequest` and `HttpResponse` API. Code written for `dart:io` works unchanged.

## The native library

A build hook (`hook/build.dart`) gets the Rust library. It tries these in order:

1. A path you set in your app `pubspec.yaml` (`hooks: user_defines: dox_http_native: lib_path: ...`).
2. A ready-built library from the GitHub release, checked with sha256.
   There are builds for macOS (arm64, x64), Linux (x64, arm64) and Windows (x64).
3. A build from source with `cargo`, when Rust is installed.

So on these systems you do not need Rust.
Use `dart run`, `dart test` or `dart build cli`. `dart compile exe` does not run build hooks.

## Use it

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

## Turn it off in Dox

- Set `server: ServerBackend.dartIo` in `AppConfig`.
- Or set the env var `DOX_SERVER=dartio`. The env var wins over the config.

Dox also uses `dart:io` by itself when the native library does not load,
and when the app has WebSocket or Socket.IO routes.

## Features

- Each isolate can bind the same port (`SO_REUSEPORT` on Linux, one shared socket on macOS).
- Each isolate has its own Rust network thread. `DOX_HTTP_THREAD=shared` puts them on one thread.
- `400` for bad requests, `431` for headers over 16 KB, `413` for bodies over `maxBodySize` (`maxMultipartSize` for a multipart form). A too big `Content-Length` with `Expect: 100-continue` gets `413` before the body is sent. Any other too big body is read and dropped first, so the client sees the `413`.
- `408` when the client sends no body bytes for `bodyTimeout` (idle time, default 120 seconds). A slow but steady upload is fine.
- `bind(port, address: '127.0.0.1')` listens on one host. With no address it listens on all interfaces.
- `close()` is graceful: no new connections, open requests get their answer, then it completes. `close(force: true)` closes every connection at once.
- Not yet: WebSocket upgrade (`detachSocket`).
- Not yet: streaming a response while it is written. The body is sent on `close`.

## Documentation

- [Native server](https://dartondox.dev/latest/digging-deeper/native-server/)
- [API reference](https://pub.dev/documentation/dox_http_native/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/develop/LICENSE).

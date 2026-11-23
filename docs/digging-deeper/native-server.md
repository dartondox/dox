---
icon: lucide/server
---

# Native server

Dox runs on a native HTTP server from the package `dox_http_native`: Rust owns the sockets and parses HTTP, and all your code stays in Dart.

## Setup

Every Dox app uses the native server, and you do not need Rust. The package gets a ready-built library for your system when you build the app. See [Performance](performance.md) for the numbers.

Build with `dox build` or `dart build cli`. `dart compile exe` does not run build hooks, so the app has no library. See [Deployment](deployment.md).

### Limits

| Limit | Value | Answer |
| --- | --- | --- |
| Request line and headers | 16 KB | 431 |
| Body | `maxBodySize` (10 MB) | 413 |
| Multipart form | `maxMultipartSize` (100 MB) | 413 |
| No body bytes for | `bodyTimeout` (120 seconds) | 408 |
| Request head arrives in | `idleTimeout` (30 seconds) | connection closed |
| Keep-alive connection with no request | `idleTimeout` (30 seconds) | connection closed |
| Both `Content-Length` and chunked | - | 400 |
| Transfer encoding other than chunked | - | 501 |

These are the defaults of `AppConfig`, where you can change them. See [App config](../reference/app-config.md).

## Writing handlers

The server has the same API as the `dart:io` `HttpServer`, so code for `dart:io` keeps working. Each isolate runs the server on its own thread, so a slow synchronous handler blocks all the sockets of its isolate. An `await` gives the isolate back.

## When the library does not load

Dox stops at start and the error says why and how to fix it:

```
Unsupported operation: dox_http_native did not load: <reason>.
Fix: install Rust (cargo, see https://rustup.rs), then run the app again ...
```

A reason like `native library ABI 8, expected 9` means the library on disk is from another version of the package. See [Troubleshooting](../reference/troubleshooting.md#the-native-http-library-did-not-load).

## HTTP/2

The native server also speaks HTTP/2 (h2c) on the same port, with `http2: true`. See [HTTP/2](http2.md).

## WebSocket

`NativeWebSocket.upgrade(request)` gives a `dart:io` `WebSocket`. Your route, middleware and the `Origin` check run first, and a normal answer (like 403) refuses the upgrade:

```dart
if (NativeWebSocket.isUpgradeRequest(request)) {
  WebSocket socket = await NativeWebSocket.upgrade(request,
      protocol: 'chat', maxMessageSize: 64 * 1024);
}
```

A message over `maxMessageSize` (16 MB by default) closes the socket with code 1009. On a graceful stop, every open socket gets code 1001.

### Finding lost clients

Set `pingInterval` to find clients that vanished with no close, like a phone that lost its network. When the client stays quiet for two intervals, the socket closes with 1001:

```dart
socket.pingInterval = Duration(seconds: 30);
```

## Streaming a response

Write with `add()` and call `flush()`. The first `flush()` sends the status, the headers and the bytes so far:

```dart
import 'dart:convert';
import 'dart:io';

server.listen((HttpRequest req) async {
  req.response.headers.contentType = ContentType('text', 'event-stream');
  req.response.add(utf8.encode('data: hello\n\n'));
  await req.response.flush();
});
```

A streamed response with a `contentLength` must send exactly that many bytes, or `add()` or `close()` fails.

### Checking the response state

Cast `req.response` to `NativeResponse` to read its state. `headSent` is true when the status and headers went out, so no error page can go out after it. `isGone` is true when the client left, and `gone` completes when it leaves:

```dart
NativeResponse res = req.response as NativeResponse;
bool sent = res.headSent;
bool left = res.isGone;
await Future.any(<Future<void>>[res.gone, res.done]);
```

`gone` never completes for a response that ends normally, so always race it against `done` or a timeout.

## Security notes

- On the internet, run the app behind a reverse proxy like Caddy or nginx. The proxy does HTTPS and buffers slow clients.
- Set `maxConnections` when the app port is open to the internet.
- Another process of the same OS user can bind the same port. Do not run untrusted code as the user of the app.
- `req.uri` resolves `..` in the path. Never build a file path from the raw path. Use the storage helpers.

## Where the library comes from

The build hook of `dox_http_native` uses the first one that works:

1. A path in the root `pubspec.yaml` of your app:

    ```yaml
    hooks:
      user_defines:
        dox_http_native:
          lib_path: /path/to/libdox_http_native.so
    ```

2. A local build in `native/target/release` of the package.
3. The ready-built library from the GitHub release, checked with sha256. There are builds for macOS (arm64, x64), Linux (x64, arm64) and Windows (x64).
4. A build from source with `cargo`, when Rust is installed.

For a git or path dependency, step 4 comes before step 3. When none works, the app stops at start with the error above.

## How it works

The server runs on the thread of the isolate, in a loop:

1. Dart calls Rust (one FFI call).
2. Rust writes the answers of the last batch, reads the sockets and parses the new requests. It gives them back to Dart as one batch.
3. Dart runs your handlers and calls Rust again with their answers.

When the isolate has nothing to do, a small helper thread watches the sockets and wakes it. The OS spreads connections, not requests, between the [isolates](isolate.md). So a few busy connections (like from one proxy) can keep some isolates idle. Use more connections than isolates.

## Without Dox

`dox_http_native` also works on its own, in any Dart app:

```bash
dart pub add dox_http_native
```

Bind a server and listen for requests, like with the `dart:io` `HttpServer`:

```dart
import 'dart:io';

import 'package:dox_http_native/dox_http_native.dart';

Future<void> main() async {
  NativeHttpServer server = await NativeHttpServer.bind(3000);
  server.listen((HttpRequest req) async {
    req.response.write('Hello World');
    await req.response.close();
  });
}
```

With no address, the server listens on all interfaces. These are the options of `bind`:

```dart
NativeHttpServer.bind(
  3000,
  address: '127.0.0.1',
  maxConnections: 10000, // no limit by default
  maxBodySize: 10 * 1024 * 1024,
  maxMultipartSize: 50 * 1024 * 1024,
  bodyTimeout: Duration(seconds: 120),
  idleTimeout: Duration(seconds: 30),
  http2: true, // see HTTP/2
);
```

At `maxConnections`, the server stops accepting until a connection closes. Behind a load balancer, set `idleTimeout` longer than the idle timeout of the balancer, or clients can get 502.

### Checking the library

`NativeHttpServer.isAvailable` is true when the native library loads. `loadError` says why it did not, and `ensureAvailable()` throws that error:

```dart
if (!NativeHttpServer.isAvailable) print(NativeHttpServer.loadError);
```

### Stopping the server

`close()` waits for open requests. `close(force: true)` closes every connection at once. `isOpen` is false after the close:

```dart
await server.close();
```

### Encrypting with AES-GCM

`AesGcm` does AES-256-GCM in Rust. Dox uses it for encrypted cookies. The key is 32 bytes, and `open` gives null when the data or the `aad` is wrong:

```dart
Uint8List sealed = AesGcm.seal(key, plain, aad);
Uint8List? plain2 = AesGcm.open(key, sealed, aad);
```

## Working on the native code

`dox_http_native` lives in its own repo: [dartondox/dox-http-native](https://github.com/dartondox/dox-http-native). The Rust code is in its `native` folder:

```bash
cd dox-http-native/native
cargo build --release   # the hook uses this build from now on
cargo test
cd .. && dart test --concurrency=1
```

To use your local copy in the Dox repo, see [Contribute](../community/contribute.md#native-packages).

## Next steps

- [HTTP/2](http2.md): turn on HTTP/2.
- [Performance](performance.md): the benchmark numbers.
- [Isolate](isolate.md): one server per CPU core.

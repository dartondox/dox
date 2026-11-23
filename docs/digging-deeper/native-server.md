---
icon: lucide/server
---

# Native server

Dox runs on a native HTTP server from the package `dox_http_native`.

You do not need to set anything. Every app uses it, also an app with WebSocket or Socket.IO routes. Rust owns the sockets and parses HTTP, but all your code stays in Dart: routes, controllers, DTOs, middleware and the ORM. It gets about 5 times more requests than the `dart:io` server on one or two cores. See [Performance](performance.md).

You do not need Rust. The package downloads a ready-built library for your system when you build the app.

## Without Dox

`dox_http_native` also works on its own, in any Dart app. Add the package:

```bash
dart pub add dox_http_native
```

Then bind a server and listen for requests. The API is the same as the `dart:io` `HttpServer`:

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

With no address, the server listens on all interfaces. To listen on one host, pass `address`:

```dart
NativeHttpServer.bind(3000, address: '127.0.0.1');
```

If the port is open to the internet, set `maxConnections`. At the limit, the server stops accepting new connections until one closes. There is no limit by default:

```dart
NativeHttpServer.bind(3000, maxConnections: 10000);
```

`close()` waits for open requests. `close(force: true)` closes every connection at once.

The rest of this page is the same with or without Dox.

## Writing handlers

Because the server has the same API as `dart:io`, `req.httpRequest`, `HttpResponse` and code written for `dart:io` keep working.

Each isolate runs the server on its own thread. So a slow synchronous handler holds all the sockets of its isolate until it is done. `await` is fine, because it gives the isolate back.

## When the library does not load

If the native library can not load, Dox stops at start, before any isolate runs. The error says why and how to fix it:

```
Unsupported operation: dox_http_native did not load: <reason>.
Fix: install Rust (cargo, see https://rustup.rs), then run the app again ...
```

`<reason>` is for example `native library ABI 8, expected 9`. This means the library on disk is from another version of the package. See [Troubleshooting](../reference/troubleshooting.md#the-native-http-library-did-not-load).

You must build with `dox build` or `dart build cli`, because `dart compile exe` does not run build hooks, so it has no library. See [Deployment](deployment.md).

## HTTP/2

The native server also speaks HTTP/2 (h2c) on the same port, when you turn it on with `http2: true`. See [HTTP/2](http2.md).

## WebSocket

Rust also does the WebSocket upgrade and the WebSocket protocol. Your route, middleware and the `Origin` check run first, like for any request. If they give a normal answer (like `403`), the upgrade is refused.

In your own code, use `NativeWebSocket.upgrade(request)`. It gives a `dart:io` `WebSocket`:

```dart
WebSocket socket = await NativeWebSocket.upgrade(request);
```

A message over the size limit closes the socket with code `1009`. Set the limit with `maxMessageSize` of `NativeWebSocket.upgrade`. Socket.IO uses `maxHttpBufferSize`.

To find clients that vanished with no close (like a phone that lost its network), set `pingInterval`. When the client sent nothing for that long, the server sends a ping. When it still sends nothing for one more interval, the socket closes with `1001`. It is off by default:

```dart
socket.pingInterval = Duration(seconds: 30);
```

On a graceful stop (SIGTERM), every open WebSocket gets close code `1001`.

## Streaming a response

To send a body in parts, like server-sent events, write with `add()` and call `flush()`. The first `flush()` sends the status, the headers and the bytes so far. Later writes go out at once:

```dart
import 'dart:convert';
import 'dart:io';

server.listen((HttpRequest req) async {
  req.response.headers.contentType = ContentType('text', 'event-stream');
  req.response.add(utf8.encode('data: hello\n\n'));
  await req.response.flush();
});
```

`NativeResponse.headSent` is `true` once the status and headers went out. After that, an error page can not be sent any more. The response can only end. `req.response` is an `HttpResponse`, so cast it to read the flag:

```dart
bool sent = (req.response as NativeResponse).headSent;
```

## Security notes

- On the internet, run it behind a reverse proxy like Caddy or nginx. The proxy does HTTPS, buffers slow clients and caps connections.
- Set `maxConnections` when the app port is open to the internet.
- Another process of the same OS user can bind the same port. So do not run untrusted code as the user of the app.
- `req.uri` resolves `..` in the path. Never build a file path from the raw path. Use the storage helpers.

## Where the library comes from

The build hook of `dox_http_native` (`hook/build.dart`) picks the first one that works:

1. A path you give in the root `pubspec.yaml` of your app:

    ```yaml
    hooks:
      user_defines:
        dox_http_native:
          lib_path: /path/to/libdox_http_native.so
    ```

2. A local build in `native/target/release` of the package (for work on the package itself).
3. The ready-built library from the GitHub release, checked with sha256. There are builds for macOS (arm64, x64), Linux (x64, arm64) and Windows (x64).
4. A build from source with `cargo`, when Rust is installed.

For a git or path dependency, step 4 comes before step 3, because the source can be newer than the release.

When none works, the app still builds, but it stops at start with the error above. Install Rust and run it again, so step 4 works.

## Working on the native code

`dox_http_native` lives in its own repo: [dartondox/dox-http-native](https://github.com/dartondox/dox-http-native). The Rust code is in its `native` folder:

```bash
cd dox-http-native/native
cargo build --release   # the hook uses this build from now on
cargo test
cd .. && dart test --concurrency=1
```

To use your local copy in the Dox repo, or to release the package, see [Contribute](../community/contribute.md#native-packages).

## Details

### How it works

The server runs on the thread of the isolate, in a loop:

1. Dart calls Rust (one FFI call).
2. Rust writes the answers of the last batch, reads the sockets and parses the new requests. It gives them back to Dart as one batch.
3. Dart runs your handlers and calls Rust again with their answers.

- Under load there is no other thread, so a request never waits for a thread to wake up. When the isolate has nothing to do, a small helper thread watches the sockets and wakes the isolate once when a request comes.
- A second helper thread does gzip, only with `compress: true`. Under load both helper threads sleep.
- The loop gives the event loop a turn after a few batches, so timers and database answers still run on time.
- Each isolate runs its own server on the same port. See [Isolate](isolate.md). The OS spreads connections, not requests, so a keep-alive connection stays on one isolate. A few busy connections (like from one proxy) can keep some isolates idle, so use more connections than isolates.
- WebSocket: Rust sends the `101` answer, answers pings, does the close handshake, checks that text is UTF-8 and checks the size of each frame. Dart gets whole messages in the same batches as requests.
- Compression (permessage-deflate) is never agreed, because a small compressed message could grow very big in memory.

### Limits

- The request line plus headers can be at most 16 KB. Bigger gets `431`. A bad request gets `400`.
- A multipart form over `maxMultipartSize`, or any other body over `maxBodySize`, gets `413` from Rust. With `Expect: 100-continue`, the `413` comes before the body is sent. Else Rust reads and drops the body first, so the client sees the `413`.
- A client that sends no body bytes for 120 seconds gets `408`. A slow but steady upload is fine.
- Accepted sockets get TCP keep-alive. After 60 seconds with no traffic, the OS checks the client every 10 seconds, and a client that misses 6 checks (about 2 minutes) is closed. A live client always answers.
- A client that closed its side while the handler has not answered is closed when nothing was written for `idleTimeout` (30 seconds by default). Set it with the `idleTimeout` argument of `NativeHttpServer.bind`. In a Dox app, set `AppConfig.idleTimeout`.
- A request head must arrive within 30 seconds. A keep-alive connection with no request for 30 seconds is closed. A client that does not read its answer for 30 seconds is cut off.
- A request with both `Content-Length` and `Transfer-Encoding: chunked` gets `400`. A transfer encoding other than `chunked` gets `501`.
- At most 64 requests of one connection wait for an answer, and at most 1 MB of answers waits to be sent. Then the server stops reading that connection until the answers go out.
- A streamed response with a `contentLength` must send exactly that many bytes. `add()` throws when the body passes it, and `close()` fails when it is shorter.
- A streamed response over 64 KB goes out in parts, and at most 1 MB of it waits in memory. Dart reads more of a file only when the client has read what was sent, and stops when the client leaves.
- A request body of 64 KB or more goes to Dart without a copy.
- `compress: true` in `AppConfig` gzips on a helper thread. A streamed response is not compressed.
- WebSocket: one turn reads at most 256 KB of one socket, so one busy client can not hold the isolate. While more than 256 KB waits to be sent to a client, the server stops reading its frames.

## See also

- [HTTP/2](http2.md): turn on HTTP/2.
- [Performance](performance.md): the benchmark numbers.

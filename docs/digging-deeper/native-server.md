# Native server

Dox runs on a native HTTP server. It comes from the package
`dox_http_native`. You do not need to set anything. Every app uses it, also
an app with WebSocket or Socket.IO routes.

- Rust ([hyper](https://hyper.rs)) owns the sockets and parses HTTP.
- All your code stays in Dart: routes, controllers, DTOs, middleware, ORM.
- It is much faster than the `dart:io` server. In a hello world test on one
  core it served about 5 times more requests. See [Performance](performance.md).

You do not need Rust. The package downloads a ready-built library for your
system when you build the app.

## How it works

1. Rust reads the requests from the sockets.
2. It sends the requests to Dart in batches (one message per batch).
3. Dart runs your handlers, like before.
4. Dart sends all answers back to Rust in one call.

The native server has the same API as the `dart:io` `HttpServer`. So
`req.httpRequest`, `HttpResponse` and code written for `dart:io` keep working.

Each isolate runs its own server on the same port:

- Linux: one socket per isolate (`SO_REUSEPORT`). The kernel spreads the
  connections.
- macOS: the isolates share one socket.
- Windows: only one isolate serves HTTP.

The OS spreads connections, not requests. A keep-alive connection stays on
one isolate. So a few busy connections (eg. from one proxy or a load test
with few connections) can keep some isolates idle. Use more connections
than isolates.

## When the library does not load

Dox stops at start, before any isolate runs. The error says why and how to
fix it:

```
Unsupported operation: dox_http_native did not load: <reason>.
Fix: install Rust (cargo, see https://rustup.rs), then run the app again ...
```

`<reason>` is for example `native library ABI 4, expected 5`: the library on
disk is from another version of the package. See
[Troubleshooting](../reference/troubleshooting.md#the-native-http-library-did-not-load).

## WebSocket

Rust also does the WebSocket upgrade and the WebSocket protocol.

1. Rust marks a request that asks for an upgrade.
2. Dart runs the route, the middleware and the `Origin` check, like for any
   request. A normal answer (eg. `403`) refuses the upgrade.
3. When Dart accepts, Rust sends the `101` answer. From then on Rust
   answers pings, does the close handshake, checks that text is UTF-8 and
   checks the size of each message.
4. Dart gets whole messages, in the same batches as requests. It sends
   messages back the same way as answers.

- A message or frame over the size limit closes the socket with code `1009`.
  Dart never reads it. `dox_websocket` uses `maxMessageSize`, Socket.IO uses
  `maxHttpBufferSize`.
- Compression (permessage-deflate) is never agreed. A small compressed
  message could grow very big in memory.
- On a graceful stop (SIGTERM), every open WebSocket gets close code `1001`.
- In your own code, use `NativeWebSocket.upgrade(request)` from
  `dox_http_native`. It gives a `dart:io` `WebSocket`.

## Threads

Each isolate has its own Rust network thread. `DOX_HTTP_THREAD=shared` puts
all isolates on one thread. It is off by default: on 2 cores the one thread
was the limit and req/s fell by a quarter. Leave it off unless you measure
a gain.

## Limits

- Max size of the request line plus headers: 16 KB. Bigger gets `431`.
- A bad request gets `400`.
- A multipart form over `maxMultipartSize`, or any other body over
  `maxBodySize`, gets `413` from Rust. When `Content-Length` is too big and
  the client sent `Expect: 100-continue`, the `413` comes before the body is
  sent. Else Rust reads and drops the body first, so the client sees the
  `413`. Dart checks the limits again.
- A client that sends no body bytes for 120 seconds (idle time) gets `408`.
  A slow but steady upload is fine.
- A small response is sent in one piece when it is closed. A streamed
  response (a file, a download, any `Stream`) over 64 KB goes out in
  parts: the client gets the first bytes early. At most 1 MB of it waits
  in memory. Dart reads more of the file only when the client has read
  what was sent. When the client leaves, Dart stops reading.
- A request body of 64 KB or more goes to Dart without a copy.
- `compress: true` works: Rust gzips the body on another thread, so the
  isolate does not wait. A streamed response is not compressed.

## Where the library comes from

The build hook of `dox_http_native` (`hook/build.dart`) picks the first one
that works:

1. A path you give in the root `pubspec.yaml` of your app:

    ```yaml
    hooks:
      user_defines:
        dox_http_native:
          lib_path: /path/to/libdox_http_native.so
    ```

2. A local build in `native/target/release` of the package (for work on
   Dox itself).
3. The ready-built library from the GitHub release, checked with sha256.
   There are builds for macOS (arm64, x64), Linux (x64, arm64) and
   Windows (x64).
4. A build from source with `cargo`, when Rust is installed.

When none works, the app still builds, but it stops at start with the
error above. Install Rust and run it again, so step 4 works.

!!! note "Use `dart build cli`"
    `dart compile exe` does not run build hooks. Use `dox build` or
    `dart build cli`. See [Deployment](deployment.md).

## Work on the native code

The Rust code is in `packages/dox-http-native/native`.

```bash
cd packages/dox-http-native/native
cargo build --release   # the hook uses this build from now on
cargo test
cd .. && dart test --concurrency=1
```

To make a release of the libraries, push a tag like
`dox_http_native-v3.0.0-alpha.4`. The version in the tag must be the
`version` in `packages/dox-http-native/pubspec.yaml`, because the build hook
downloads from the tag of its own version.

The `Native` workflow builds the 5 libraries and uploads them with a
`SHA256SUMS` file. Copy the hashes into `_sha256` in `hook/build.dart` before
you publish the package.

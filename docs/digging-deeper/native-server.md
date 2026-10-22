# Native server

Dox runs on a native HTTP server by default. It comes from the package
`dox_http_native`. You do not need to set anything.

- Rust ([hyper](https://hyper.rs)) owns the sockets and parses HTTP.
- All your code stays in Dart: routes, controllers, DTOs, middleware, ORM.
- It is about 3 times faster than the `dart:io` server for small requests.
  See [Performance](performance.md).

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

## Use dart:io instead

Set `server` in `AppConfig`:

```dart
AppConfig(
  // ...
  server: ServerBackend.dartIo,
);
```

Or set the env var `DOX_SERVER=dartio`. The env var wins over the config.

Dox also uses `dart:io` by itself in these cases:

- The native library did not load. Dox prints one warning line at start:
  `[dox] warning: dox_http_native did not load, using the dart:io server (...)`.
- The app has WebSocket or Socket.IO routes. The native server can not
  upgrade a connection to WebSocket yet.

`DOX_SERVER=native` forces the native server, also for an app with WebSocket
routes. WebSocket upgrades then fail with 500. Socket.IO long-polling works.

Each isolate has its own Rust network thread. `DOX_HTTP_THREAD=shared` puts
all isolates on one thread. It is off by default: on 2 cores the one thread
was the limit and req/s fell by a quarter. Leave it off unless you measure
a gain.

## Limits

- Max size of the request line plus headers: 16 KB. Bigger gets `431`.
- A bad request gets `400`.
- A body over the bigger of `maxBodySize` and `maxMultipartSize` gets `413`
  from Rust. Each body type is checked again in Dart with its own limit.
- A response is sent when it is closed. It is kept in memory until then,
  also a big file. Use a proxy (nginx, Caddy) or a storage link for big
  downloads.
- No WebSocket upgrade yet (see above).
- `compress: true` works: Dart gzips the body.

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

When none works, the app still builds and runs on `dart:io`.

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
`dox_http_native-v3.0.0-alpha.2`. The `Native` workflow builds the 5
libraries and uploads them with a `SHA256SUMS` file. Copy the hashes into
`_sha256` in `hook/build.dart` before you publish the package.

---
icon: lucide/layers
---

# HTTP/2

Dox can speak HTTP/2 on the same port as HTTP/1.1. You need it for [gRPC](grpc.md), because gRPC only runs over HTTP/2. It also helps when your proxy talks HTTP/2 to the app: many requests share one connection, so there are fewer connections and less waiting.

It is off by default, so nothing changes until you turn it on.

## Turn it on

Set `http2` in `AppConfig`:

```dart
AppConfig(
  http2: true,
);
```

Your routes, middleware and controllers do not change. `req.protocolVersion` is `2.0` for an HTTP/2 request, and `1.0` or `1.1` for the others.

Without Dox, pass `http2: true` to `NativeHttpServer.bind`.

## How it works

- It is h2c only: HTTP/2 over plain TCP. There is no TLS in Dox. TLS stays at your proxy.
- HTTP/1.1 and HTTP/2 share one port. The server looks at the first bytes of each connection and picks the right one. Old clients and health checks keep working.
- A browser does not speak h2c. It talks HTTP/2 to your proxy, and the proxy talks to Dox. See [Deployment: HTTP/2 and gRPC](deployment.md#http2-and-grpc).
- The HTTP/2 code is part of the [native server](native-server.md), in Rust. It passes the h2spec conformance suite in strict mode.

## maxConcurrentStreams

One HTTP/2 connection can carry many requests at once. `maxConcurrentStreams` is the most open requests one connection can have. The default is `250`. Keep it unless you have a reason:

```dart
AppConfig(
  http2: true,
  maxConcurrentStreams: 100,
);
```

## Protection

HTTP/2 has known attacks: a client can open and cancel requests very fast, or send floods of small frames. Dox guards against them for you:

- **Fast cancels (Rapid Reset).** A request that the client cancels still counts against `maxConcurrentStreams` until your handler really ends. So a client can not pile up work in your app by cancelling requests fast. A normal client whose calls time out now and then is not cut.
- **Floods.** A client that sends too many resets, `SETTINGS`, `PING`s or empty frames gets `GOAWAY ENHANCE_YOUR_CALM`, and its connection closes.
- **Memory and time.** Request bodies have the same limits as on HTTP/1.1 (`maxBodySize`, `maxMultipartSize`, `bodyTimeout`). A connection with no open request closes after `idleTimeout`. An answer that the client does not read for 30 seconds is stopped.

There is nothing to set up. Still, keep a proxy in front of Dox on the internet, as the [deployment guide](deployment.md) says.

## Performance

HTTP/2 can send many requests on one connection at once. On one isolate, that gives about 1.6x the requests a second of HTTP/1.1. Turning `http2` on does not slow down HTTP/1.1 clients.

| Load                                        | Requests a second |
| ------------------------------------------- | ----------------- |
| HTTP/1.1, 256 connections, `http2` off      | 364,000           |
| HTTP/1.1, 256 connections, `http2` on       | 373,000           |
| HTTP/2, 16 connections × 16 requests each   | 587,000           |
| HTTP/2, 4 connections × 64 requests each    | 465,000           |

How it was run:

- The app has one route, `GET /`, that answers `Hello, World!`. It ran with one isolate, AOT-compiled (`dart build cli`).
- Linux containers on one 8-core machine. The server had 4 cores and the load tool ([oha](https://github.com/hatoo/oha)) had the other 4.
- Each number is the median of 3 runs of 10 seconds, after 3 seconds of warm up.

With 4 isolates, HTTP/1.1 and HTTP/2 both reached about 630,000 requests a second. That is the limit of the load tool on 4 cores, not of Dox.

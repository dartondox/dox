---
icon: lucide/arrow-right-left
---

# HTTP/2

HTTP/2 lets one connection carry many requests at the same time, and Dox can serve it on the same port as HTTP/1.1.

There are two reasons to use it:

- You want to serve [gRPC](grpc.md). gRPC only works over HTTP/2.
- Your proxy talks HTTP/2 to the app. It then sends many requests on a few connections, so the app does more work with fewer connections.

HTTP/2 is off by default. If you do not turn it on, nothing changes.

## Turning on HTTP/2

Set `http2` to `true` in the app config:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  // ...
);
```

The port now takes both HTTP/1.1 and HTTP/2. Dox picks the right one for each connection, so old clients and health checks keep working.

Your routes, middleware and controllers stay the same.

## Checking the protocol of a request

If you need to know how a request came in, read `req.protocolVersion`. It is `2.0` for an HTTP/2 request, and `1.0` or `1.1` for the others:

```dart
Route.get('/protocol', (DoxRequest req) {
  return req.protocolVersion; // '2.0'
});
```

You can try it with curl:

```bash
curl --http2-prior-knowledge http://localhost:3000/protocol
```

## Limiting requests per connection

One HTTP/2 connection can have many open requests. `maxConcurrentStreams` is the most that one connection can have at the same time. The default is `250`, and it fits most apps.

Set a lower number if you want each client to hold fewer open requests:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  maxConcurrentStreams: 100,
  // ...
);
```

## Running behind a proxy

Dox speaks h2c, which is HTTP/2 over plain TCP. It has no TLS, so TLS stays at your proxy.

Browsers only speak HTTP/2 with TLS. So a browser talks HTTP/2 to the proxy, and the proxy talks to Dox:

```text
browser  --HTTP/2 + TLS-->  proxy  --h2c or HTTP/1.1-->  Dox
```

See [Deployment: HTTP/2 and gRPC](deployment.md#http2-and-grpc) for the Caddy and nginx config.

## Using the server without Dox

If you use the [native server](native-server.md) on its own, pass the same two options to `NativeHttpServer.bind`:

```dart
NativeHttpServer server = await NativeHttpServer.bind(
  3000,
  http2: true,
  maxConcurrentStreams: 100,
);
```

## Protection

HTTP/2 has some known attacks. Dox guards against them by default, so there is nothing to set:

- **Fast cancels (Rapid Reset).** A client can open requests and cancel them very fast to pile up work in your app. In Dox, a cancelled request still counts against `maxConcurrentStreams` until your handler really ends, so this does not work. A normal client with a few timeouts is not cut.
- **Floods.** If a client sends too many resets, `SETTINGS`, `PING`s or empty frames, Dox answers `GOAWAY ENHANCE_YOUR_CALM` and closes the connection.
- **Big or slow bodies.** A request body has the same limits as on HTTP/1.1: `maxBodySize`, `maxMultipartSize` and `bodyTimeout`. See [Size limits](../the-basic/request.md#size-limits).
- **Idle and slow clients.** A connection with no open request closes after `idleTimeout`. If a client does not read an answer for 30 seconds, Dox stops that answer.

You should still keep a proxy in front of Dox on the internet, as the [deployment guide](deployment.md) says.

## Benchmark

HTTP/2 is faster when a client sends many requests on one connection. On one isolate, it handles about 1.6 times the requests of HTTP/1.1.

<div class="dox-bench dox-bench--simple" markdown>

<p class="dox-bench__title">One isolate: HTTP/2 is 1.6× faster</p>
<p class="dox-bench__sub"><code>GET /</code> answers <code>Hello, World!</code>. The server has 4 cores and runs one isolate.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>HTTP/2</strong><span>16 conn × 16 requests</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">587,000<span class="dox-bench__vs">fastest</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>HTTP/2</strong><span>4 conn × 64 requests</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 79.2%"></span></span>
    <span class="dox-bench__num">465,000<span class="dox-bench__vs">1.3× slower</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>HTTP/1.1</strong><span>256 conn, http2 on</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 63.5%"></span></span>
    <span class="dox-bench__num">373,000<span class="dox-bench__vs">1.6× slower</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>HTTP/1.1</strong><span>256 conn, http2 off</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 62%"></span></span>
    <span class="dox-bench__num">364,000<span class="dox-bench__vs">1.6× slower</span></span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · one isolate · Linux · oha · median of 3 runs</span></p>

</div>

The two HTTP/1.1 rows are almost the same. So turning `http2` on does not slow down your HTTP/1.1 clients.

| Load                                       | Requests a second |
| ------------------------------------------ | ----------------: |
| HTTP/1.1, 256 connections, `http2` off     | 364,000           |
| HTTP/1.1, 256 connections, `http2` on      | 373,000           |
| HTTP/2, 16 connections × 16 requests each  | 587,000           |
| HTTP/2, 4 connections × 64 requests each   | 465,000           |

With 4 isolates, HTTP/1.1 and HTTP/2 both reach about 630,000 requests a second. That is the limit of the load tool on 4 cores, not the limit of Dox. So the gain of HTTP/2 shows most when the app has few isolates.

### How it was run

- The app has one route, `GET /`, that answers `Hello, World!`. It is an AOT build (`dart build cli`).
- Everything ran in Linux containers on one 8-core machine. The server had 4 cores, and the load tool ([oha](https://github.com/hatoo/oha)) had the other 4.
- Each number is the median of 3 runs of 10 seconds, after 3 seconds of warm up.

## Details

- Dox passes all 146 tests of the [h2spec](https://github.com/summerwind/h2spec) conformance suite in strict mode.
- `maxConcurrentStreams` must be 1 or more. It is used only when `http2` is `true`.

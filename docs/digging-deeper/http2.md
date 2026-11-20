---
icon: lucide/arrow-right-left
---

# HTTP/2

With HTTP/2, one connection can send many requests at the same time, and Dox serves HTTP/2 on the same port as HTTP/1.1.

Use HTTP/2 for one of these reasons:

- You want to serve [gRPC](grpc.md). gRPC works only over HTTP/2.
- Your proxy sends HTTP/2 to the app. The proxy then sends many requests on a small number of connections. The app does the same work with fewer connections.

HTTP/2 is off by default. If you do not turn it on, Dox does not change.

## Turn on HTTP/2

Set `http2` to `true` in the app config:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  // ...
);
```

The port then accepts HTTP/1.1 and HTTP/2. Old clients and health checks continue to work, because Dox finds the protocol of each connection.

You do not change your routes, middleware, or controllers.

## Read the protocol of a request

To find the protocol of a request, read `req.protocolVersion`. The value is `2.0` for an HTTP/2 request. For an HTTP/1.x request, the value is `1.0` or `1.1`:

```dart
Route.get('/protocol', (DoxRequest req) {
  return req.protocolVersion; // '2.0'
});
```

You can do a test with curl:

```bash
curl --http2-prior-knowledge http://localhost:3000/protocol
```

## Limit the open requests on one connection

One HTTP/2 connection can have many open requests. `maxConcurrentStreams` sets the maximum number of open requests on one connection. The default is `250`. This value is correct for most apps.

To let each client keep fewer open requests, set a lower number:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  maxConcurrentStreams: 100,
  // ...
);
```

## Use a proxy

Dox uses h2c. h2c is HTTP/2 over plain TCP, without TLS. Your proxy must do the TLS.

Browsers use HTTP/2 only with TLS. The browser sends HTTP/2 with TLS to the proxy, and the proxy sends the requests to Dox:

```text
browser  --HTTP/2 + TLS-->  proxy  --h2c or HTTP/1.1-->  Dox
```

For the Caddy and nginx config, see [Deployment: HTTP/2 and gRPC](deployment.md#http2-and-grpc).

## Use the server without Dox

If you use the [native server](native-server.md) without Dox, give the same two options to `NativeHttpServer.bind`:

```dart
NativeHttpServer server = await NativeHttpServer.bind(
  3000,
  http2: true,
  maxConcurrentStreams: 100,
);
```

## Protection

HTTP/2 has some known attacks. Dox has protection against these attacks by default. You do not set anything.

- **Rapid Reset.** A client can open requests and cancel them very quickly. This adds work to your app. In Dox, a cancelled request stays in the `maxConcurrentStreams` count until your handler stops. For this reason, the attack does not work. Dox does not close the connection of a normal client that has some timeouts.
- **Floods.** If a client sends too many resets, `SETTINGS` frames, `PING` frames, or empty frames, Dox sends `GOAWAY ENHANCE_YOUR_CALM`. Then Dox closes the connection.
- **Large or slow bodies.** A request body on HTTP/2 has the same limits as on HTTP/1.1: `maxBodySize`, `maxMultipartSize`, and `bodyTimeout`. See [Size limits](../the-basic/request.md#size-limits).
- **Idle and slow clients.** A connection with no open request closes after `idleTimeout`. If a client does not read a response for 30 seconds, Dox stops that response.

On the internet, keep a proxy in front of Dox. See the [deployment guide](deployment.md).

## Benchmark

HTTP/2 is faster when a client sends many requests on one connection. On one isolate, HTTP/2 does approximately 1.6 times the requests of HTTP/1.1.

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

The two HTTP/1.1 rows are almost the same. Thus, `http2: true` does not make your HTTP/1.1 clients slower.

| Load                                       | Requests a second |
| ------------------------------------------ | ----------------: |
| HTTP/1.1, 256 connections, `http2` off     | 364,000           |
| HTTP/1.1, 256 connections, `http2` on      | 373,000           |
| HTTP/2, 16 connections × 16 requests each  | 587,000           |
| HTTP/2, 4 connections × 64 requests each   | 465,000           |

With 4 isolates, HTTP/1.1 and HTTP/2 both do approximately 630,000 requests a second. This number is the limit of the load tool on 4 cores, not the limit of Dox. HTTP/2 gives the largest increase when the app has few isolates.

### Test setup

- The app has one route, `GET /`. This route sends `Hello, World!`.
- The app is an AOT build. The build command is `dart build cli`.
- All tests ran in Linux containers on one machine with 8 cores. The server used 4 cores. The load tool, [oha](https://github.com/hatoo/oha), used the other 4 cores.
- Each number is the median of 3 runs. Each run took 10 seconds, after a warm up of 3 seconds.

## Details

- Dox passes all 146 tests of the [h2spec](https://github.com/summerwind/h2spec) conformance suite in strict mode.
- `maxConcurrentStreams` must be 1 or more. Dox uses it only when `http2` is `true`.

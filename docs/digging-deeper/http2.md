---
icon: lucide/arrow-right-left
---

# HTTP/2

Dox serves HTTP/2 on the same port as HTTP/1.1, so one connection can send many requests at the same time.

Turn it on to serve [gRPC](grpc.md), or when your proxy sends HTTP/2 to the app. HTTP/2 is off by default.

## Setup

Set `http2` to true in the app config. The port then accepts HTTP/1.1 and HTTP/2, and your routes stay the same:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  // ...
);
```

## Read the protocol of a request

`req.protocolVersion` is `2.0` for an HTTP/2 request, and `1.0` or `1.1` for HTTP/1.x:

```dart
Route.get('/protocol', (DoxRequest req) {
  return req.protocolVersion; // '2.0'
});
```

Test it with curl:

```bash
curl --http2-prior-knowledge http://localhost:3000/protocol
```

## Limit the open requests on one connection

`maxConcurrentStreams` is the most open requests on one connection. The default is 250:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  maxConcurrentStreams: 100,
  // ...
);
```

## Use a proxy

Dox speaks **h2c**: HTTP/2 over plain TCP, with no TLS. Browsers use HTTP/2 only with TLS, so your proxy does the TLS:

```text
browser  --HTTP/2 + TLS-->  proxy  --h2c or HTTP/1.1-->  Dox
```

For the Caddy and nginx config, see [Deployment: HTTP/2 and gRPC](deployment.md#http2-and-grpc).

## Protection

Dox has protection against the known HTTP/2 attacks by default:

- A cancelled request stays in the `maxConcurrentStreams` count until your handler stops. This stops the Rapid Reset attack.
- Too many resets, `SETTINGS` frames, `PING` frames or empty frames close the connection with `GOAWAY ENHANCE_YOUR_CALM`.
- A request body has the same limits as on HTTP/1.1. See [Size limits](../the-basic/request.md#size-limits).
- A connection with no open request closes after `idleTimeout`.

## Benchmark

On one isolate, HTTP/2 does approximately 1.6 times the requests of HTTP/1.1, when a client sends many requests on one connection.

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

The two HTTP/1.1 rows are almost the same, so `http2: true` does not make HTTP/1.1 clients slower.

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


## Without Dox

With the [native server](native-server.md) on its own, give the same options to `NativeHttpServer.bind`. `http2ResetBurst` and `http2ResetRate` limit the resets of one connection. Raise them behind a proxy that sends many cancels:

```dart
NativeHttpServer server = await NativeHttpServer.bind(
  3000,
  http2: true,
  maxConcurrentStreams: 100,
  http2ResetBurst: 1000,
  http2ResetRate: 100, // a second
);
```

## Next steps

- [gRPC](grpc.md): gRPC services on the same server.
- [Native server](native-server.md): the server below Dox.
- [Deployment](deployment.md): put a proxy in front.

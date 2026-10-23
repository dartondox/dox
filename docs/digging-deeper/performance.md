# Performance

This page shows how fast Dox is, and how to keep your app fast in production.

The short version:

1. Build with `dox build` and run the AOT binary. Never `dart run` in production.
2. Put Caddy or nginx in front for HTTPS and gzip.
3. Keep the default isolates (one per CPU core).
4. Keep the body limits on. Uploads stream to disk.

## Benchmark

A "hello world" test. Each server answers `GET /` with the plain text
`Hello World`. Dox is a small real Dox app with one route.

Hello world only measures framework overhead. A real app spends most of its
time on the database, JSON and your own code, so the gaps are much smaller
there.

### 1 core

| Server                        | req/s   | p99 ms | CPU % | peak MB |
| ----------------------------- | ------: | -----: | ----: | ------: |
| Dox, native server            | 171,042 | 0.92   | 100   | 9       |
| Dox, `dart:io` server         | 33,154  | 5.48   | 101   | 39      |
| Bun 1.4.3                     | 181,162 | 1.13   | 101   | 14      |
| Node 24.22.0                  | 81,909  | 2.26   | 101   | 54      |
| Pure Rust hyper (the ceiling) | 254,349 | 0.47   | 100   | 5       |

On one core, Dox with the native server is about as fast as Bun (0.94x).
It is 5x faster than Dox on `dart:io`.

How it was run:

- Docker on an Apple M2 (8 CPUs in the Docker VM), `linux/arm64`.
- The server and wrk run in two containers, pinned to different CPUs:
  server on CPU 0, wrk on CPUs 2-7.
- wrk 4.2.0, 100 connections (the tables) and 256 connections.
  5 seconds warm-up, then 3 runs of 10 seconds. The tables show the median.
- CPU % and peak memory come from `docker stats`. 100% = one core.
- Dart 3.13.6, Rust 1.99.1. Dox is built with `dart build cli` (this is
  what `dox build` does). The build hook of `dox_http_native` builds the
  Rust library with cargo.
- `DOX_SERVER=dartio` runs the same Dox app on `dart:io`.

## App benchmark

A small real app, the same in each language: `GET /json` returns a map,
`GET /db` reads one row by id from Postgres, `GET /queries?n=20` reads 20
rows one after another. The table has 10,000 rows. Each server runs alone
on one or two pinned CPUs, Postgres 18 and wrk on other CPUs, 256
connections, 4 database connections per core, 3 runs of 10 seconds, median.
Versions: Dox 3.0.0-alpha.3 (native server, `dox_postgres_native`), Go 1.27
(`net/http` + pgx), Bun 1.4 (`Bun.serve` + `Bun.sql`), Node 24
(`node:http` + `pg`), `dart:io` (`HttpServer` + `package:postgres`).

### 1 core

<div class="dox-bench" markdown>

<p class="dox-bench__title">1 core: 1.5× Bun, 2.3× Go</p>
<p class="dox-bench__sub"><code>GET /db</code>: read one row from Postgres. Requests per second, higher is better.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>native server + driver</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">85,381<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">5.65 ms</span>
    <span class="dox-bench__ram">24 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.serve + Bun.sql</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 67.5%"></span></span>
    <span class="dox-bench__num">57,614<span class="dox-bench__vs">1.5× slower</span></span>
    <span class="dox-bench__p99">6.11 ms</span>
    <span class="dox-bench__ram">36 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http + pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 43%"></span></span>
    <span class="dox-bench__num">36,706<span class="dox-bench__vs">2.3× slower</span></span>
    <span class="dox-bench__p99">14.49 ms</span>
    <span class="dox-bench__ram">18 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>+ package:postgres</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 14.2%"></span></span>
    <span class="dox-bench__num">12,146<span class="dox-bench__vs">7.0× slower</span></span>
    <span class="dox-bench__p99">47.62 ms</span>
    <span class="dox-bench__ram">62 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox 3.0.0-alpha.3 · Bun 1.4 · Go 1.27 · Dart 3.13 · Postgres 18 · 256 connections · wrk · median of 3 runs</span></p>

</div>

| Route            | Dox     | Bun     | Go     | `dart:io` |
| ---------------- | ------: | ------: | -----: | --------: |
| /json req/s      | 157,036 | 176,148 | 79,884 | 33,670    |
| /db req/s        | 85,381  | 57,614  | 36,706 | 12,146    |
| /queries req/s   | 9,745   | 10,097  | 3,810  | 966       |
| /db p99 ms       | 5.65    | 6.11    | 14.49  | 47.62     |
| /db peak MB      | 24      | 36      | 18     | 62        |

### 2 cores

<div class="dox-bench" markdown>

<p class="dox-bench__title">2 cores: still the fastest</p>
<p class="dox-bench__sub"><code>GET /db</code> on 2 CPU cores. Dox runs one isolate per core; Bun and Node one worker process per core.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>2 isolates</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">138,514<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">3.62 ms</span>
    <span class="dox-bench__ram">51 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>2 workers</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 93.1%"></span></span>
    <span class="dox-bench__num">128,998<span class="dox-bench__vs">1.1× slower</span></span>
    <span class="dox-bench__p99">5.61 ms</span>
    <span class="dox-bench__ram">57 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>2 workers + pg</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 44.5%"></span></span>
    <span class="dox-bench__num">61,611<span class="dox-bench__vs">2.2× slower</span></span>
    <span class="dox-bench__p99">8.06 ms</span>
    <span class="dox-bench__ram">297 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http + pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 35.7%"></span></span>
    <span class="dox-bench__num">49,393<span class="dox-bench__vs">2.8× slower</span></span>
    <span class="dox-bench__p99">8.53 ms</span>
    <span class="dox-bench__ram">22 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox 3.0.0-alpha.3 · Bun 1.4 · Go 1.27 · Node 24 · Postgres 18 · 256 connections · wrk · median of 3 runs</span></p>

</div>

<div class="dox-bench dox-bench--simple" markdown>

<p class="dox-bench__title">2 cores: 20 queries per request</p>
<p class="dox-bench__sub"><code>GET /queries?n=20</code>: 20 reads from Postgres, one after another, in one request.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>2 isolates</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">12,902<span class="dox-bench__vs">fastest</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>2 workers</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 85.3%"></span></span>
    <span class="dox-bench__num">11,006<span class="dox-bench__vs">1.2× slower</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>2 workers + pg</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 45.5%"></span></span>
    <span class="dox-bench__num">5,870<span class="dox-bench__vs">2.2× slower</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http + pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 39.8%"></span></span>
    <span class="dox-bench__num">5,134<span class="dox-bench__vs">2.5× slower</span></span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox 3.0.0-alpha.3 · Bun 1.4 · Go 1.27 · Node 24 · Postgres 18 · 256 connections · wrk · median of 3 runs</span></p>

</div>

| Route            | Dox     | Bun     | Go      | Node    |
| ---------------- | ------: | ------: | ------: | ------: |
| /json req/s      | 251,427 | 385,553 | 175,009 | 156,389 |
| /db req/s        | 138,514 | 128,998 | 49,393  | 61,611  |
| /queries req/s   | 12,902  | 11,006  | 5,134   | 5,870   |
| /db p99 ms       | 3.62    | 5.61    | 8.53    | 8.06    |
| /db peak MB      | 51      | 57      | 22      | 297     |

Dox runs one isolate per core, Bun and Node one worker process per core.
On the database routes Dox is ahead of all of them on 2 cores, and its p99
is the lowest. On `/json` Bun is faster: its server is C++ and calls the
JavaScript handler on the same thread, while Dox hands each batch of
requests from the Rust thread to the Dart isolate.

Dox on `dart:io` with the Dart `postgres` driver is 4 to 10 times slower
than Dox with the native server and driver. Keep both on.

### Dart VM flags

We tried a bigger young generation (`DART_VM_OPTIONS=--new_gen_semi_max_size=64`
and `128`) for a better p99. Over 5 runs the change was inside the noise,
and memory did not move. So there is no flag to set. Dox never sets VM
flags for you. `DART_VM_OPTIONS` is read by the AOT binary from
`dox build`, so you can try your own.

## Request body limits

Dox reads a body while it streams in, and stops once it is too big.
It answers `413 Payload Too Large`. It checks `Content-Length` first, so a
big upload is refused before one byte is read. It also counts bytes while
reading, so a client that sends no `Content-Length` (chunked) is stopped too.

```dart
AppConfig(
  maxBodySize: 10 * 1024 * 1024,        // JSON and urlencoded, default 10 MB
  maxMultipartSize: 100 * 1024 * 1024,  // form-data uploads, default 100 MB
);
```

Set the same limit in the proxy (`client_max_body_size` in nginx).

## File uploads

- A file up to 1 MB stays in memory.
- A bigger file is written to a temp file while it arrives. So a big upload
  does not fill the memory.
- The temp file is deleted when the response is done. So save it before you
  return from the controller.

```dart
RequestFile file = req.input('video');

file.length;          // size in bytes
await file.size;      // size in KB
file.stream();        // read it in chunks
await file.store('videos');           // to storage (a cheap move on local disk)
await file.moveTo('/data/videos/1.mp4');
await file.bytes;     // whole file in memory. avoid for big files
```

## Big responses

Return a `Stream<List<int>>` or a `File`. Dox pipes it to the client and does
not load it all into memory.

```dart
Route.get('/video', (DoxRequest req) => File('storage/video.mp4'));
```

A `File` response sets `Content-Type` (from the file name),
`Content-Length` and `Accept-Ranges`. It answers `Range: bytes=...` with
`206 Partial Content`, so video players can seek and downloads can resume.

`Storage().stream()` and `Storage().download()` on the local disk also stream
the file and send `Content-Length`.

JSON and text responses are encoded once, straight to bytes, with
`Content-Length` set.

## gzip

gzip in Dart is off by default.

```dart
AppConfig(compress: true);
```

- It saves bandwidth, but costs CPU on every response, in the same isolate
  that serves requests.
- A proxy (Caddy, nginx) does it better. Turn it on in Dart only when there
  is no proxy.
- With `compress: true`, text and JSON responses are sent chunked, without
  `Content-Length`, because `dart:io` only gzips when the length is not set.

## Logging

`LogMiddleware` prints one JSON line per request. Writing to stdout blocks
the isolate. So Dox collects log lines and writes them every 20 ms (or every
64 KB) in one write. If the process is killed hard, the last 20 ms of request logs can
be lost. Errors from `Logger` are still written right away.

Turn `LogMiddleware` off when a proxy already writes access logs.

## What Dox does for you

- Routes are grouped by method. The regex of each route is built once, not
  on every request.
- The argument types of each controller are read once at start, not on
  every request.

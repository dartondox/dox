---
icon: lucide/gauge
---

# Performance

This page shows how fast Dox is, and how to keep your app fast in production.

The short version:

1. Build with `dox build` and run the AOT binary. Never `dart run` in production.
2. Put Caddy or nginx in front for HTTPS and gzip.
3. Keep the default isolates (one per CPU core).
4. Keep the body limits on. Uploads stream to disk.

## Benchmark

The rules of [the-benchmarker/web-frameworks](https://github.com/the-benchmarker/web-frameworks):
each server answers `GET /` (empty body), `GET /user/:id` (the id) and
`POST /user` (empty body). Dox is a full Dox app with these three routes.
"Dox server only" is `dox_http_native` with no framework, to show what the
framework costs.

This only measures the HTTP stack. A real app spends most of its time on
the database, JSON and your own code, so the gaps are smaller there. See
[App benchmark](#app-benchmark).

### 2 cores

<div class="dox-bench" markdown>

<p class="dox-bench__title">2 cores: ahead of Rust hyper and Bun</p>
<p class="dox-bench__sub"><code>GET /</code>, 256 connections. Every server has one worker per core: Dox one isolate, Bun and Node one process, Go and Rust one thread.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>full app</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">631,399<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">1.2 ms</span>
    <span class="dox-bench__ram">58 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>hyper</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 93.4%"></span></span>
    <span class="dox-bench__num">589,565<span class="dox-bench__vs">1.07× slower</span></span>
    <span class="dox-bench__p99">0.8 ms</span>
    <span class="dox-bench__ram">15 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.serve</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 83.6%"></span></span>
    <span class="dox-bench__num">528,153<span class="dox-bench__vs">1.2× slower</span></span>
    <span class="dox-bench__p99">1.0 ms</span>
    <span class="dox-bench__ram">68 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>node:http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 43.9%"></span></span>
    <span class="dox-bench__num">277,430<span class="dox-bench__vs">2.3× slower</span></span>
    <span class="dox-bench__p99">2.2 ms</span>
    <span class="dox-bench__ram">252 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 38%"></span></span>
    <span class="dox-bench__num">240,239<span class="dox-bench__vs">2.6× slower</span></span>
    <span class="dox-bench__p99">3.2 ms</span>
    <span class="dox-bench__ram">44 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>HttpServer</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 20%"></span></span>
    <span class="dox-bench__num">126,371<span class="dox-bench__vs">5× slower</span></span>
    <span class="dox-bench__p99">11.0 ms</span>
    <span class="dox-bench__ram">49 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Rust 1.99 · Bun 1.4 · Node 26 · Go 1.26 · Dart 3.13 · 2 cores · 256 connections · wrk</span></p>

</div>

Requests per second on `GET /` at 64, 256 and 512 connections:

| Server              | 64      | 256     | 512     | p99 at 256 | peak MB |
| ------------------- | ------: | ------: | ------: | ---------: | ------: |
| Dox                 | 508,470 | 631,399 | 626,278 | 1.23 ms    | 58      |
| Dox server only     | 572,947 | 694,841 | 711,105 | 0.74 ms    | 30      |
| Rust (hyper)        | 493,065 | 589,565 | 561,625 | 0.77 ms    | 15      |
| Bun (`Bun.serve`)   | 484,601 | 528,153 | 545,820 | 0.96 ms    | 68      |
| Node (`node:http`)  | 257,777 | 277,430 | 266,678 | 2.17 ms    | 252     |
| Go (`net/http`)     | 246,725 | 240,239 | 230,382 | 3.15 ms    | 44      |
| `dart:io`           | 113,847 | 126,371 | 134,586 | 11.01 ms   | 49      |

The other two routes at 256 connections:

| Server            | `GET /user/:id` | `POST /user` |
| ----------------- | --------------: | -----------: |
| Dox               | 556,714         | 504,889      |
| Dox server only   | 672,334         | 683,219      |
| Rust (hyper)      | 555,040         | 554,464      |
| Bun               | 501,058         | 516,647      |
| Node              | 267,704         | 271,067      |
| Go                | 229,308         | 232,366      |
| `dart:io`         | 96,341          | 119,633      |

### 1 core

| Server          | 64      | 256     | 512     | peak MB |
| --------------- | ------: | ------: | ------: | ------: |
| Dox             | 331,016 | 355,868 | 355,513 | 50      |
| Dox server only | 361,034 | 398,202 | 392,098 | 24      |
| `dart:io`       | 62,640  | 62,271  | 62,265  | 48      |

On one core Dox serves about 5.5 times more requests than `dart:io`.

### Why it is fast

The server runs on the isolate's own thread. One FFI call writes the
answers, reads the sockets and parses the new requests. Dart runs the
handlers and calls again. A request never waits for another thread to
wake up. A small helper thread only watches the sockets while the isolate
has nothing to do. See [Native server](native-server.md#how-it-works).

A profile with `perf` (4 server cores, 64 connections) shows the effect:

| | Dox | Bun |
| --- | ---: | ---: |
| CPU time per request | 4.85 µs | 5.5 µs |
| Context switches per request | 0.08 | 0.035 |

### How it was run

- Docker on an Apple M2 (8 CPUs in the Docker VM), `linux/arm64`.
- One server at a time. The server and wrk run in two containers on
  different CPUs: the server on 2 CPUs (or 1), wrk on the other 6. Host
  network, keep-alive.
- wrk 4.1, 64, 256 and 512 connections, 5 seconds warm-up, then 15 seconds
  per route.
- Every server has as many workers as server CPUs.
- Peak memory is the peak of the container (all workers).
- Dart 3.13.6, AOT build with `dart build cli` (this is what `dox build`
  does). Node 26.12, Bun 1.4.4, Go 1.26, Rust 1.99 with hyper 1.

## App benchmark

A small real app, the same in each language: `GET /json` returns a map,
`GET /db` reads one row by id from Postgres, `GET /queries?n=20` reads 20
rows one after another. The table has 10,000 rows. Each server runs alone
on one or two pinned CPUs, Postgres 18 and wrk on other CPUs, 256
connections, 4 database connections per core, 3 runs of 10 seconds, median.
Versions: Dox (native server, `dox_postgres_native`), Go 1.27
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

<p class="dox-bench__foot"><span>Dox · Bun 1.4 · Go 1.27 · Dart 3.13 · Postgres 18 · 256 connections · wrk · median of 3 runs</span></p>

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

<p class="dox-bench__foot"><span>Dox · Bun 1.4 · Go 1.27 · Node 24 · Postgres 18 · 256 connections · wrk · median of 3 runs</span></p>

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

<p class="dox-bench__foot"><span>Dox · Bun 1.4 · Go 1.27 · Node 24 · Postgres 18 · 256 connections · wrk · median of 3 runs</span></p>

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
is the lowest.

Dox on `dart:io` with the Dart `postgres` driver is 4 to 10 times slower
than Dox with the native server and driver. Keep both on.

### Dart VM flags

We tried a bigger young generation (`DART_VM_OPTIONS=--new_gen_semi_max_size=64`
and `128`) for a better p99. Over 5 runs the change was inside the noise,
and memory did not move. So there is no flag to set. Dox never sets VM
flags for you. `DART_VM_OPTIONS` is read by the AOT binary from
`dox build`, so you can try your own.

## Database drivers

One find-by-id query, AOT build (`dart build cli`), database on the same machine (Apple M-series), one isolate:

| Database | One query at a time | Many queries in flight | App CPU time per query |
| --- | --- | --- | --- |
| Postgres 14 (4 connections) | 60 µs | 12.5 µs each (64 in flight) | |
| MySQL 8.4 (10 connections) | 67 µs | 11 µs each (32 in flight) | 13.5 µs |
| MariaDB 11 (10 connections) | 63 µs | 9.7 µs each (32 in flight) | 12.4 µs |

- The CPU time counts the Dart thread and the Rust thread. For MySQL, it is about 75,000 queries per second on one core.
- Dart sends many queries to Rust in one call. Rust sends many results back in one message.
- One query alone spends most of its time on the trip to the database. Many requests at the same time, like in a web server, get the most out of the driver.

## Bodies, uploads and big responses

These are on by default. You only need to keep them:

- A body over `maxBodySize` or `maxMultipartSize` gets `413` from the native server, before Dart reads it. Set the same limit in the proxy. See [Size limits](../the-basic/request.md#size-limits).
- An upload over 1 MB streams to a temp file, so it does not fill the memory. See [Request](../the-basic/request.md#requestfile).
- A `File` or `Stream` response is streamed, not loaded into memory. See [Files and big responses](../the-basic/response.md#files-and-big-responses).

## gzip

gzip in Dart is off by default.

```dart
AppConfig(compress: true);
```

- It saves bandwidth, but costs CPU on every response. The native server
  gzips on a Rust thread. Streamed responses are not compressed.
- A proxy (Caddy, nginx) does it better. Turn it on in Dart only when there
  is no proxy.
- Only a body over 256 bytes is gzipped, and only when the client accepts
  gzip. The gzipped body still gets a `Content-Length`.

## Logging

`LogMiddleware` prints one JSON line per request. Writing to stdout blocks
the isolate. So Dox collects log lines and writes them every 20 ms (or every
64 KB) in one write. If the process is killed hard, the last 20 ms of request logs can
be lost. Errors from `Logger` are still written right away.

Turn `LogMiddleware` off when a proxy already writes access logs. The new
project does this for you: `enabled` is `false` when `APP_ENV` is
`production` or not set.

Leave `responseHandler` unset when you do not need it. With no handler, a
plain value (text, map, list) is sent without building a `DoxResponse`.

## What Dox does for you

- Routes are grouped by method. The regex of each route is built once, not
  on every request.
- The argument types of each controller are read once at start, not on
  every request.
- JSON and text responses are encoded once, straight to bytes, with
  `Content-Length` set.

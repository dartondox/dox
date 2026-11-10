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
    <span class="dox-bench__num">638,067<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">0.7 ms</span>
    <span class="dox-bench__ram">19 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>hyper</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 91.8%"></span></span>
    <span class="dox-bench__num">585,658<span class="dox-bench__vs">1.09× slower</span></span>
    <span class="dox-bench__p99">0.7 ms</span>
    <span class="dox-bench__ram">13 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.serve</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 78.6%"></span></span>
    <span class="dox-bench__num">501,529<span class="dox-bench__vs">1.27× slower</span></span>
    <span class="dox-bench__p99">1.0 ms</span>
    <span class="dox-bench__ram">40 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>node:http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 45%"></span></span>
    <span class="dox-bench__num">286,847<span class="dox-bench__vs">2.2× slower</span></span>
    <span class="dox-bench__p99">1.7 ms</span>
    <span class="dox-bench__ram">200 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 37.9%"></span></span>
    <span class="dox-bench__num">242,043<span class="dox-bench__vs">2.6× slower</span></span>
    <span class="dox-bench__p99">3.3 ms</span>
    <span class="dox-bench__ram">36 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>HttpServer</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 20.3%"></span></span>
    <span class="dox-bench__num">129,796<span class="dox-bench__vs">4.9× slower</span></span>
    <span class="dox-bench__p99">3.8 ms</span>
    <span class="dox-bench__ram">75 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Rust 1.99 · Bun 1.4 · Node 26 · Go 1.26 · Dart 3.13 · 2 cores · 256 connections · wrk</span></p>

</div>

Requests per second on `GET /` at 64, 256 and 512 connections:

| Server              | 64      | 256     | 512     | p99 at 256 | peak MB |
| ------------------- | ------: | ------: | ------: | ---------: | ------: |
| Dox                 | 494,223 | 638,067 | 612,032 | 0.74 ms    | 19      |
| Dox server only     | 589,866 | 692,705 | 699,938 | 0.68 ms    | 16      |
| Rust (hyper)        | 499,734 | 585,658 | 560,181 | 0.71 ms    | 13      |
| Bun (`Bun.serve`)   | 508,243 | 501,529 | 531,310 | 1.00 ms    | 40      |
| Node (`node:http`)  | 252,866 | 286,847 | 296,257 | 1.70 ms    | 200     |
| Go (`net/http`)     | 248,951 | 242,043 | 232,687 | 3.27 ms    | 36      |
| `dart:io`           | 125,428 | 129,796 | 132,112 | 3.83 ms    | 75      |

The other two routes at 256 connections:

| Server            | `GET /user/:id` | `POST /user` |
| ----------------- | --------------: | -----------: |
| Dox               | 572,658         | 545,986      |
| Dox server only   | 672,098         | 683,477      |
| Rust (hyper)      | 564,411         | 569,313      |
| Bun               | 482,328         | 498,518      |
| Node              | 274,067         | 301,084      |
| Go                | 230,845         | 231,050      |
| `dart:io`         | 93,561          | 126,027      |

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
  different CPUs: the server on 2 CPUs, wrk on the other 6. Host
  network, keep-alive.
- wrk 4.1, 64, 256 and 512 connections, 5 seconds warm-up, then 15 seconds
  per route.
- Every server has as many workers as server CPUs.
- Peak memory is the peak of the container (all workers).
- Dart 3.13.6, AOT build with `dart build cli` (this is what `dox build`
  does). `dox_core` and `dox_http_native` as released when these numbers were measured. Node 26.12, Bun 1.4.4, Go 1.26, Rust 1.99 with hyper 1.

## App benchmark

A small real app, the same in each language: `GET /json` returns a map,
`GET /db` reads one row by id from Postgres, `GET /queries?n=20` reads 20
rows one after another. The table has 10,000 rows. Each app uses its
database driver directly, with no ORM. Dox uses `dox_postgres_native`.

<div class="dox-bench" markdown>

<p class="dox-bench__title">2 cores: one row from Postgres</p>
<p class="dox-bench__sub"><code>GET /db</code>, 256 connections. Requests per second, higher is better.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>dox_postgres_native</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">266,432<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">1.8 ms</span>
    <span class="dox-bench__ram">106 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.sql</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 74.4%"></span></span>
    <span class="dox-bench__num">198,296<span class="dox-bench__vs">1.34× slower</span></span>
    <span class="dox-bench__p99">2.1 ms</span>
    <span class="dox-bench__ram">64 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>tokio-postgres</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 48.1%"></span></span>
    <span class="dox-bench__num">128,065<span class="dox-bench__vs">2.1× slower</span></span>
    <span class="dox-bench__p99">2.6 ms</span>
    <span class="dox-bench__ram">11 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>pg</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 28.3%"></span></span>
    <span class="dox-bench__num">75,447<span class="dox-bench__vs">3.5× slower</span></span>
    <span class="dox-bench__p99">4.1 ms</span>
    <span class="dox-bench__ram">232 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 21%"></span></span>
    <span class="dox-bench__num">55,903<span class="dox-bench__vs">4.8× slower</span></span>
    <span class="dox-bench__p99">6.3 ms</span>
    <span class="dox-bench__ram">31 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>package:postgres</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 10.7%"></span></span>
    <span class="dox-bench__num">28,598<span class="dox-bench__vs">9.3× slower</span></span>
    <span class="dox-bench__p99">14.2 ms</span>
    <span class="dox-bench__ram">47 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Bun 1.4 · Rust 1.99 · Node 26 · Go 1.26 · Dart 3.13 · Postgres 18 · 2 cores · 256 connections · wrk</span></p>

</div>

All three routes at 256 connections, requests per second:

| Server                           | `/json` | `/db`   | `/queries?n=20` | peak MB |
| -------------------------------- | ------: | ------: | --------------: | ------: |
| Dox (`dox_postgres_native`)      | 555,216 | 266,432 | 17,772          | 106     |
| Bun (`Bun.sql`)                  | 564,362 | 198,296 | 18,994          | 64      |
| Rust (hyper + `tokio-postgres`)  | 667,718 | 128,065 | 9,312           | 11      |
| Node (`node:http` + `pg`)        | 205,774 | 75,447  | 7,458           | 232     |
| Go (`net/http` + pgx)            | 206,398 | 55,903  | 6,635           | 31      |
| `dart:io` (+ `package:postgres`) | 89,480  | 28,598  | 2,269           | 47      |

- On one query per request, Dox is the fastest: 1.3 times Bun.
- On 20 queries per request, Dox and Bun are about the same. Postgres is
  the limit here. Both are about twice as fast as Rust.

The same app on MySQL 8.4 (`dox_mysql_native`). The `dart:io` app has no
MySQL version.

| Server                           | `/json` | `/db`   | `/queries?n=20` | peak MB |
| -------------------------------- | ------: | ------: | --------------: | ------: |
| Dox (`dox_mysql_native`)         | 558,886 | 247,242 | 12,347          | 70      |
| Bun (`Bun.sql`)                  | 561,340 | 201,923 | 12,676          | 65      |
| Rust (hyper + `mysql_async`)     | 653,244 | 46,795  | 3,158           | 10      |
| Node (`node:http` + `mysql2`)    | 205,630 | 74,809  | 6,001           | 239     |
| Go (`net/http` + `go-sql-driver`)| 211,713 | 55,322  | 5,520           | 27      |

How it was run: the same rig as the [benchmark](#how-it-was-run) above.
The server gets 2 CPUs, the database gets 2 CPUs and wrk gets the other 4.
Each server has 4 database connections per core, 8 in total. One run of 15
seconds per route. `dox_postgres_native` and `dox_mysql_native` as released when these numbers were measured.

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

`LogMiddleware` logs one line per request through `Logger`. Writing to stdout
blocks the isolate. So `Logger` collects log lines and writes them every 20 ms
(or every 64 KB) in one write. A `warn`, `warning`, `danger` or `error` line is written right away,
with the waiting lines before it, so the order stays. The buffer is also
written when the app stops. If the process is killed hard, the last 20 ms of
logs can be lost.

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

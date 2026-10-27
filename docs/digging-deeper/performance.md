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
    <span class="dox-bench__num">640,951<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">0.8 ms</span>
    <span class="dox-bench__ram">56 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>hyper</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 92%"></span></span>
    <span class="dox-bench__num">589,565<span class="dox-bench__vs">1.09× slower</span></span>
    <span class="dox-bench__p99">0.8 ms</span>
    <span class="dox-bench__ram">15 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.serve</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 82.4%"></span></span>
    <span class="dox-bench__num">528,153<span class="dox-bench__vs">1.2× slower</span></span>
    <span class="dox-bench__p99">1.0 ms</span>
    <span class="dox-bench__ram">68 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>node:http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 43.3%"></span></span>
    <span class="dox-bench__num">277,430<span class="dox-bench__vs">2.3× slower</span></span>
    <span class="dox-bench__p99">2.2 ms</span>
    <span class="dox-bench__ram">252 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 37.5%"></span></span>
    <span class="dox-bench__num">240,239<span class="dox-bench__vs">2.7× slower</span></span>
    <span class="dox-bench__p99">3.2 ms</span>
    <span class="dox-bench__ram">44 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>HttpServer</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 19.7%"></span></span>
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
| Dox                 | 523,641 | 640,951 | 633,856 | 0.84 ms    | 56      |
| Dox server only     | 587,671 | 687,520 | 695,779 | 0.90 ms    | 32      |
| Rust (hyper)        | 493,065 | 589,565 | 561,625 | 0.77 ms    | 15      |
| Bun (`Bun.serve`)   | 484,601 | 528,153 | 545,820 | 0.96 ms    | 68      |
| Node (`node:http`)  | 257,777 | 277,430 | 266,678 | 2.17 ms    | 252     |
| Go (`net/http`)     | 246,725 | 240,239 | 230,382 | 3.15 ms    | 44      |
| `dart:io`           | 113,847 | 126,371 | 134,586 | 11.01 ms   | 49      |

The other two routes at 256 connections:

| Server            | `GET /user/:id` | `POST /user` |
| ----------------- | --------------: | -----------: |
| Dox               | 556,877         | 505,741      |
| Dox server only   | 663,978         | 681,310      |
| Rust (hyper)      | 555,040         | 554,464      |
| Bun               | 501,058         | 516,647      |
| Node              | 267,704         | 271,067      |
| Go                | 229,308         | 232,366      |
| `dart:io`         | 96,341          | 119,633      |

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
  does). Node 26.12, Bun 1.4.4, Go 1.26, Rust 1.99 with hyper 1.

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
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.sql</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">194,858<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">2.2 ms</span>
    <span class="dox-bench__ram">66 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Dox</strong><span>dox_postgres_native</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 76.5%"></span></span>
    <span class="dox-bench__num">148,975<span class="dox-bench__vs">1.3× slower</span></span>
    <span class="dox-bench__p99">5.1 ms</span>
    <span class="dox-bench__ram">76 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>tokio-postgres</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 66.3%"></span></span>
    <span class="dox-bench__num">129,216<span class="dox-bench__vs">1.5× slower</span></span>
    <span class="dox-bench__p99">2.9 ms</span>
    <span class="dox-bench__ram">11 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>pg</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 36.3%"></span></span>
    <span class="dox-bench__num">70,693<span class="dox-bench__vs">2.8× slower</span></span>
    <span class="dox-bench__p99">5.7 ms</span>
    <span class="dox-bench__ram">229 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 29.2%"></span></span>
    <span class="dox-bench__num">56,829<span class="dox-bench__vs">3.4× slower</span></span>
    <span class="dox-bench__p99">6.2 ms</span>
    <span class="dox-bench__ram">27 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>package:postgres</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 14.6%"></span></span>
    <span class="dox-bench__num">28,448<span class="dox-bench__vs">6.8× slower</span></span>
    <span class="dox-bench__p99">14.1 ms</span>
    <span class="dox-bench__ram">47 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Bun 1.4 · Rust 1.99 · Node 26 · Go 1.26 · Dart 3.13 · Postgres 18 · 2 cores · 256 connections · wrk</span></p>

</div>

All three routes at 256 connections, requests per second:

| Server                           | `/json` | `/db`   | `/queries?n=20` | peak MB |
| -------------------------------- | ------: | ------: | --------------: | ------: |
| Dox (`dox_postgres_native`)      | 565,920 | 148,975 | 18,378          | 76      |
| Bun (`Bun.sql`)                  | 544,250 | 194,858 | 18,278          | 66      |
| Rust (hyper + `tokio-postgres`)  | 677,954 | 129,216 | 9,082           | 11      |
| Node (`node:http` + `pg`)        | 189,768 | 70,693  | 6,970           | 229     |
| Go (`net/http` + pgx)            | 204,654 | 56,829  | 6,550           | 27      |
| `dart:io` (+ `package:postgres`) | 88,656  | 28,448  | 2,274           | 47      |

- On one query per request, only Bun is faster than Dox.
- On 20 queries per request, Dox and Bun are the same, and both are about
  twice as fast as Rust.
- The same app with the ORM query builder (`dox_orm`) gets about 131,000
  on `/db` and 12,500 on `/queries`. The query builder costs a little time
  per query.

How it was run: the same rig as the [benchmark](#how-it-was-run) above.
The server gets 2 CPUs, Postgres 18 gets 2 CPUs and wrk gets the other 4.
Each server has 4 database connections per core, 8 in total. One run of 15
seconds per route.

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

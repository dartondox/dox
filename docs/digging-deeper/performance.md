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
    <span class="dox-bench__num">612,209<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">1.9 ms</span>
    <span class="dox-bench__ram">31 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>hyper</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 95.7%"></span></span>
    <span class="dox-bench__num">586,187<span class="dox-bench__vs">1.04× slower</span></span>
    <span class="dox-bench__p99">0.7 ms</span>
    <span class="dox-bench__ram">14 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.serve</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 85.2%"></span></span>
    <span class="dox-bench__num">521,312<span class="dox-bench__vs">1.17× slower</span></span>
    <span class="dox-bench__p99">1.0 ms</span>
    <span class="dox-bench__ram">40 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>node:http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 40.6%"></span></span>
    <span class="dox-bench__num">248,734<span class="dox-bench__vs">2.5× slower</span></span>
    <span class="dox-bench__p99">6.1 ms</span>
    <span class="dox-bench__ram">256 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 38.2%"></span></span>
    <span class="dox-bench__num">233,841<span class="dox-bench__vs">2.6× slower</span></span>
    <span class="dox-bench__p99">3.7 ms</span>
    <span class="dox-bench__ram">41 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>HttpServer</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 21.7%"></span></span>
    <span class="dox-bench__num">133,133<span class="dox-bench__vs">4.6× slower</span></span>
    <span class="dox-bench__p99">3.6 ms</span>
    <span class="dox-bench__ram">49 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Rust 1.99 · Bun 1.4 · Node 26 · Go 1.26 · Dart 3.13 · 2 cores · 256 connections · wrk</span></p>

</div>

Requests per second on `GET /` at 64, 256 and 512 connections:

| Server              | 64      | 256     | 512     | p99 at 256 | peak MB |
| ------------------- | ------: | ------: | ------: | ---------: | ------: |
| Dox                 | 478,906 | 612,209 | 621,421 | 1.93 ms    | 31      |
| Dox server only     | 553,423 | 689,053 | 702,236 | 0.71 ms    | 29      |
| Rust (hyper)        | 505,598 | 586,187 | 569,172 | 0.74 ms    | 14      |
| Bun (`Bun.serve`)   | 491,058 | 521,312 | 501,042 | 1.02 ms    | 40      |
| Node (`node:http`)  | 259,079 | 248,734 | 274,097 | 6.09 ms    | 256     |
| Go (`net/http`)     | 251,736 | 233,841 | 230,541 | 3.65 ms    | 41      |
| `dart:io`           | 117,937 | 133,133 | 116,516 | 3.60 ms    | 49      |

The other two routes at 256 connections:

| Server            | `GET /user/:id` | `POST /user` |
| ----------------- | --------------: | -----------: |
| Dox               | 565,691         | 540,989      |
| Dox server only   | 661,677         | 683,698      |
| Rust (hyper)      | 554,963         | 573,318      |
| Bun               | 492,133         | 498,714      |
| Node              | 284,487         | 267,698      |
| Go                | 217,499         | 228,197      |
| `dart:io`         | 95,098          | 126,015      |

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
- Two rounds. The two Dox rows, Rust and Bun show the quieter round. The first round
  was slower for every server.
- Every server has as many workers as server CPUs.
- Peak memory is the peak of the container (all workers).
- Dart 3.13.6, AOT build with `dart build cli` (this is what `dox build`
  does). `dox_core` 3.0.2, `dox_http_native` 3.0.2. Node 26.12, Bun 1.4.4, Go 1.26, Rust 1.99 with hyper 1.

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
    <span class="dox-bench__num">264,598<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">1.8 ms</span>
    <span class="dox-bench__ram">98 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.sql</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 70%"></span></span>
    <span class="dox-bench__num">185,157<span class="dox-bench__vs">1.43× slower</span></span>
    <span class="dox-bench__p99">4.5 ms</span>
    <span class="dox-bench__ram">67 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>tokio-postgres</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 45.9%"></span></span>
    <span class="dox-bench__num">121,520<span class="dox-bench__vs">2.2× slower</span></span>
    <span class="dox-bench__p99">4.6 ms</span>
    <span class="dox-bench__ram">12 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>pg</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 26.7%"></span></span>
    <span class="dox-bench__num">70,634<span class="dox-bench__vs">3.7× slower</span></span>
    <span class="dox-bench__p99">10.4 ms</span>
    <span class="dox-bench__ram">226 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 20.5%"></span></span>
    <span class="dox-bench__num">54,257<span class="dox-bench__vs">4.9× slower</span></span>
    <span class="dox-bench__p99">8.6 ms</span>
    <span class="dox-bench__ram">25 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>package:postgres</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 10.1%"></span></span>
    <span class="dox-bench__num">26,797<span class="dox-bench__vs">9.9× slower</span></span>
    <span class="dox-bench__p99">17.6 ms</span>
    <span class="dox-bench__ram">47 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Bun 1.4 · Rust 1.99 · Node 26 · Go 1.26 · Dart 3.13 · Postgres 18 · 2 cores · 256 connections · wrk</span></p>

</div>

All three routes at 256 connections, requests per second:

| Server                           | `/json` | `/db`   | `/queries?n=20` | peak MB |
| -------------------------------- | ------: | ------: | --------------: | ------: |
| Dox (`dox_postgres_native`)      | 542,659 | 264,598 | 17,915          | 98      |
| Bun (`Bun.sql`)                  | 555,660 | 185,157 | 18,929          | 67      |
| Rust (hyper + `tokio-postgres`)  | 493,913 | 121,520 | 8,656           | 12      |
| Node (`node:http` + `pg`)        | 189,394 | 70,634  | 7,124           | 226     |
| Go (`net/http` + pgx)            | 208,008 | 54,257  | 6,163           | 25      |
| `dart:io` (+ `package:postgres`) | 85,674  | 26,797  | 2,047           | 47      |

- On one query per request, Dox is the fastest: 1.4 times Bun.
- On 20 queries per request, Dox and Bun are about the same. Postgres is
  the limit here. Both are about twice as fast as Rust.

The same app on MySQL 8.4 (`dox_mysql_native`). The `dart:io` app has no
MySQL version.

| Server                           | `/json` | `/db`   | `/queries?n=20` | peak MB |
| -------------------------------- | ------: | ------: | --------------: | ------: |
| Dox (`dox_mysql_native`)         | 525,057 | 233,381 | 12,164          | 61      |
| Bun (`Bun.sql`)                  | 567,523 | 184,639 | 12,186          | 65      |
| Rust (hyper + `mysql_async`)     | 648,290 | 45,766  | 3,141           | 11      |
| Node (`node:http` + `mysql2`)    | 188,468 | 72,880  | 7,269           | 219     |
| Go (`net/http` + `go-sql-driver`)| 207,239 | 54,490  | 5,773           | 20      |

How it was run: the same rig as the [benchmark](#how-it-was-run) above.
The server gets 2 CPUs, the database gets 2 CPUs and wrk gets the other 4.
Each server has 4 database connections per core, 8 in total. One run of 15
seconds per route. `dox_postgres_native` 3.0.2, `dox_mysql_native` 3.0.1.

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

---
icon: lucide/gauge
---

# Performance

This page shows how fast Dox is, and how to keep your app fast in production.

Dox is fast by default, so most apps only need to follow a few rules in production:

1. Build with `dox build` and run the AOT binary. Never use `dart run` in production. See [Deployment](deployment.md#build).
2. Put Caddy or nginx in front, for HTTPS and gzip.
3. Keep the default isolates, one per CPU core.
4. Keep the body limits on. Uploads stream to disk.

For the code mistakes that slow an app down, see [Performance mistakes](performance-mistakes.md).

## Bodies, uploads and big responses

Big requests and responses can fill the memory of your server. Dox protects you from this by default, so you only need to keep these settings:

- A body over `maxBodySize` or `maxMultipartSize` gets `413` from the native server, before Dart reads it. Set the same limit in the proxy. See [Size limits](../the-basic/request.md#size-limits).
- An upload over 1 MB streams to a temp file. See [Request](../the-basic/request.md#requestfile).
- A `File` or `Stream` response is streamed, not loaded into memory. See [Files and big responses](../the-basic/response.md#files-and-big-responses).

## gzip

gzip saves bandwidth, but it costs CPU on every response. A proxy like Caddy or nginx does it better. So gzip in Dart is off by default. If there is no proxy, turn it on:

```dart
AppConfig(compress: true);
```

Only a body over 256 bytes is gzipped, and only when the client accepts gzip. Streamed responses are not compressed.

## Logging

`LogMiddleware` logs one line per request. If a proxy already writes access logs, turn `LogMiddleware` off, because writing logs costs time. A new project does this for you: `enabled` is `false` when `APP_ENV` is `production` or not set.

## Response handler

Leave `responseHandler` unset if you do not need it. With no handler, a plain value (text, map, list) is sent without building a `DoxResponse`.

## Benchmark

This benchmark uses the rules of [the-benchmarker/web-frameworks](https://github.com/the-benchmarker/web-frameworks):
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
    <span class="dox-bench__num">626,655<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">1.1 ms</span>
    <span class="dox-bench__ram">21 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>hyper</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 93.5%"></span></span>
    <span class="dox-bench__num">585,658<span class="dox-bench__vs">1.07× slower</span></span>
    <span class="dox-bench__p99">0.7 ms</span>
    <span class="dox-bench__ram">13 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.serve</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 80%"></span></span>
    <span class="dox-bench__num">501,529<span class="dox-bench__vs">1.25× slower</span></span>
    <span class="dox-bench__p99">1.0 ms</span>
    <span class="dox-bench__ram">40 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>node:http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 45.8%"></span></span>
    <span class="dox-bench__num">286,847<span class="dox-bench__vs">2.2× slower</span></span>
    <span class="dox-bench__p99">1.7 ms</span>
    <span class="dox-bench__ram">200 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 38.6%"></span></span>
    <span class="dox-bench__num">242,043<span class="dox-bench__vs">2.6× slower</span></span>
    <span class="dox-bench__p99">3.3 ms</span>
    <span class="dox-bench__ram">36 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>HttpServer</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 20.7%"></span></span>
    <span class="dox-bench__num">129,796<span class="dox-bench__vs">4.8× slower</span></span>
    <span class="dox-bench__p99">3.8 ms</span>
    <span class="dox-bench__ram">75 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Rust 1.99 · Bun 1.4 · Node 26 · Go 1.26 · Dart 3.13 · 2 cores · 256 connections · wrk</span></p>

</div>

The Dox numbers are from the 3.2 patch release (2026-11-16). The other servers are from the run before, on the same Mac. See [How it was run](#how-it-was-run).

Requests per second on `GET /` at 64, 256 and 512 connections:

| Server              | 64      | 256     | 512     | p99 at 256 | peak MB |
| ------------------- | ------: | ------: | ------: | ---------: | ------: |
| Dox                 | 521,583 | 626,655 | 649,990 | 1.14 ms    | 21      |
| Dox server only     | 557,115 | 678,781 | 696,043 | 2.9 ms     | 19      |
| Rust (hyper)        | 499,734 | 585,658 | 560,181 | 0.71 ms    | 13      |
| Bun (`Bun.serve`)   | 508,243 | 501,529 | 531,310 | 1.00 ms    | 40      |
| Node (`node:http`)  | 252,866 | 286,847 | 296,257 | 1.70 ms    | 200     |
| Go (`net/http`)     | 248,951 | 242,043 | 232,687 | 3.27 ms    | 36      |
| `dart:io`           | 125,428 | 129,796 | 132,112 | 3.83 ms    | 75      |

The other two routes at 256 connections:

| Server            | `GET /user/:id` | `POST /user` |
| ----------------- | --------------: | -----------: |
| Dox               | 552,170         | 555,397      |
| Dox server only   | 661,102         | 670,326      |
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
  does). `dox_core` and `dox_http_native` as released when these numbers were measured. The Dox rows were measured again on 2026-11-16 for the 3.2 patch release (same Mac, a new Docker VM). The other servers are from the run before. Node 26.12, Bun 1.4.4, Go 1.26, Rust 1.99 with hyper 1.

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
    <span class="dox-bench__num">297,000<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">2.6 ms</span>
    <span class="dox-bench__ram">93 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.sql</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 66.8%"></span></span>
    <span class="dox-bench__num">198,296<span class="dox-bench__vs">1.5× slower</span></span>
    <span class="dox-bench__p99">2.1 ms</span>
    <span class="dox-bench__ram">64 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>tokio-postgres</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 43.1%"></span></span>
    <span class="dox-bench__num">128,065<span class="dox-bench__vs">2.3× slower</span></span>
    <span class="dox-bench__p99">2.6 ms</span>
    <span class="dox-bench__ram">11 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>pg</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 25.4%"></span></span>
    <span class="dox-bench__num">75,447<span class="dox-bench__vs">3.9× slower</span></span>
    <span class="dox-bench__p99">4.1 ms</span>
    <span class="dox-bench__ram">232 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 18.8%"></span></span>
    <span class="dox-bench__num">55,903<span class="dox-bench__vs">5.3× slower</span></span>
    <span class="dox-bench__p99">6.3 ms</span>
    <span class="dox-bench__ram">31 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>package:postgres</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 9.6%"></span></span>
    <span class="dox-bench__num">28,598<span class="dox-bench__vs">10.4× slower</span></span>
    <span class="dox-bench__p99">14.2 ms</span>
    <span class="dox-bench__ram">47 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Bun 1.4 · Rust 1.99 · Node 26 · Go 1.26 · Dart 3.13 · Postgres 18 · 2 cores · 256 connections · wrk</span></p>

</div>

The Dox numbers are from the 3.2 patch release (2026-11-16). The other servers are from the run before, on the same Mac.

All three routes at 256 connections, requests per second:

| Server                           | `/json` | `/db`   | `/queries?n=20` | peak MB |
| -------------------------------- | ------: | ------: | --------------: | ------: |
| Dox (`dox_postgres_native`)      | 592,900 | 297,000 | 18,015          | 93      |
| Bun (`Bun.sql`)                  | 564,362 | 198,296 | 18,994          | 64      |
| Rust (hyper + `tokio-postgres`)  | 667,718 | 128,065 | 9,312           | 11      |
| Node (`node:http` + `pg`)        | 205,774 | 75,447  | 7,458           | 232     |
| Go (`net/http` + pgx)            | 206,398 | 55,903  | 6,635           | 31      |
| `dart:io` (+ `package:postgres`) | 89,480  | 28,598  | 2,269           | 47      |

- On one query per request, Dox is the fastest: 1.5 times Bun.
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
seconds per route. `dox_postgres_native` and `dox_mysql_native` as released when these numbers were measured. The Postgres Dox row was measured again on 2026-11-16 for the 3.2 patch release (same Mac, a new Docker VM). The other servers and the MySQL table are from the run before.

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

## Details

### Dart VM flags

A bigger young generation (`DART_VM_OPTIONS=--new_gen_semi_max_size=64` or `128`) did not give a better p99. Over 5 runs the change was inside the noise, and memory did not move. So there is no flag to set for speed, and Dox never sets VM flags for you. `DART_VM_OPTIONS` is read by the AOT binary from `dox build`, so you can try your own.

One flag can decrease the peak memory. The Dart VM lets the old generation grow by a maximum of 140 MB before it collects garbage. When many requests wait at the same time, their objects move to the old generation, and the memory goes up and down in large steps. `DART_VM_OPTIONS=--old_gen_growth_rate=64` sets the maximum step to 32 MB. The value is a number of pages of 512 KB, and the default is 280.

In a GraphQL test on Postgres (a list of 20 rows with a relation, 2 cores, 256 connections), the peak memory went from 213 MB to 105 MB. The requests each second went down by 2% to 5%. A high peak of this type is not a memory leak: the memory after the load is the same with the flag and without it. Use the flag when the memory limit of your container is small.

### How logs are written

- `Logger` collects log lines and writes them every 20 ms (or every 64 KB) in one write, because writing to stdout blocks the isolate.
- A `warn`, `warning`, `danger` or `error` line is written right away, with the waiting lines before it, so the order stays.
- The buffer is also written when the app stops. If the process is killed hard, the last 20 ms of logs can be lost.

### What Dox does for you

- Routes are grouped by method. The regex of each route is built once, not on every request.
- The argument types of each controller are read once at start, not on every request.
- JSON and text responses are encoded once, straight to bytes, with `Content-Length` set.
- The native server gzips on a Rust thread, and the gzipped body still gets a `Content-Length`.

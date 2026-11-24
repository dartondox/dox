---
icon: lucide/gauge
---

# Performance

This page shows how fast Dox is, and how to keep your app fast in production.

## Setup

Dox is fast by default. In production, follow these rules:

1. Build with `dox build` and run the AOT binary. See [Deployment](deployment.md#build).
2. Put Caddy or nginx in front, for HTTPS and gzip.
3. Keep the default isolates, one per CPU core.
4. Keep the body limits on.

For the code mistakes that slow an app down, see [Performance mistakes](performance-mistakes.md).

## Bodies, uploads and big responses

Dox keeps big requests and responses out of the memory by default:

- A body over `maxBodySize` or `maxMultipartSize` gets 413 before Dart reads it. Set the same limit in the proxy. See [Size limits](../the-basic/request.md#size-limits).
- An upload over 1 MB streams to a temp file. See [Request](../the-basic/request.md#requestfile).
- A `File` or `Stream` response streams. See [Files and big responses](../the-basic/response.md#files-and-big-responses).

## gzip

A proxy does gzip better than Dart, so gzip in Dart is off by default. With no proxy, turn it on:

```dart
AppConfig(compress: true);
```

Dox gzips only a body over 256 bytes, for a client that accepts gzip. A streamed response is not compressed.

## Logging

`LogMiddleware` logs one line per request. A new project turns it off when `APP_ENV` is `production` or not set, because the proxy writes access logs.

`Logger` writes its lines every 20 ms in one write. If the process is killed hard, the last 20 ms of logs can be lost.

## Response handler

Leave `responseHandler` unset if you do not need it. With no handler, Dox sends a plain value (text, map, list) with no `DoxResponse`.

## Benchmark

This benchmark uses the rules of [the-benchmarker/web-frameworks](https://github.com/the-benchmarker/web-frameworks). Each server answers `GET /` (empty body), `GET /user/:id` (the id) and `POST /user` (empty body). "Dox server only" is `dox_http_native` with no framework.

It measures only the HTTP stack. A real app spends most of its time on the database and your own code. See [App benchmark](#app-benchmark).

### 2 cores

<div class="dox-bench" markdown>

<p class="dox-bench__title">2 cores: ahead of Rust hyper and Bun</p>
<p class="dox-bench__sub"><code>GET /</code>, 256 connections. Every server has one worker per core: Dox and Relic one isolate, Bun and Node one process, Go and Rust one thread.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>full app</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">652,400<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">0.7 ms</span>
    <span class="dox-bench__ram">21 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>hyper</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 87.7%"></span></span>
    <span class="dox-bench__num">572,132<span class="dox-bench__vs">1.14× slower</span></span>
    <span class="dox-bench__p99">0.8 ms</span>
    <span class="dox-bench__ram">14 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.serve</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 77.4%"></span></span>
    <span class="dox-bench__num">504,672<span class="dox-bench__vs">1.29× slower</span></span>
    <span class="dox-bench__p99">1.0 ms</span>
    <span class="dox-bench__ram">40 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Relic 2</strong><span>relic_native</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 72.2%"></span></span>
    <span class="dox-bench__num">471,005<span class="dox-bench__vs">1.39× slower</span></span>
    <span class="dox-bench__p99">0.7 ms</span>
    <span class="dox-bench__ram">40 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>node:http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 43.2%"></span></span>
    <span class="dox-bench__num">282,130<span class="dox-bench__vs">2.3× slower</span></span>
    <span class="dox-bench__p99">1.7 ms</span>
    <span class="dox-bench__ram">199 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 36.3%"></span></span>
    <span class="dox-bench__num">237,146<span class="dox-bench__vs">2.8× slower</span></span>
    <span class="dox-bench__p99">3.3 ms</span>
    <span class="dox-bench__ram">36 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>HttpServer</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 19.2%"></span></span>
    <span class="dox-bench__num">124,996<span class="dox-bench__vs">5.2× slower</span></span>
    <span class="dox-bench__p99">4.8 ms</span>
    <span class="dox-bench__ram">56 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Rust 1.99 · Bun 1.4 · Relic 2.0 · Node 26 · Go 1.26 · Dart 3.13 · 2 cores · 256 connections · wrk</span></p>

</div>

All the servers are from the same run on 2026-11-22. Each number is the median of 3 rounds. See [How it was run](#how-it-was-run).

Requests per second on `GET /` at 64, 256 and 512 connections:

| Server              | 64      | 256     | 512     | p99 at 256 | peak MB |
| ------------------- | ------: | ------: | ------: | ---------: | ------: |
| Dox                 | 541,489 | 652,400 | 669,691 | 0.74 ms    | 21      |
| Dox server only     | 576,078 | 685,300 | 701,441 | 0.70 ms    | 20      |
| Rust<br>hyper | 499,992 | 572,132 | 559,617 | 0.77 ms    | 14      |
| Bun<br>`Bun.serve` | 496,865 | 504,672 | 521,648 | 1.02 ms    | 40      |
| Relic 2<br>`relic_native` | 461,710 | 471,005 | 494,225 | 0.71 ms | 40 |
| Node<br>`node:http` | 263,438 | 282,130 | 278,923 | 1.73 ms    | 199     |
| Go<br>`net/http` | 245,400 | 237,146 | 230,919 | 3.32 ms    | 36      |
| `dart:io`           | 115,790 | 124,996 | 132,746 | 4.82 ms    | 56      |

The other two routes at 256 connections:

| Server            | `GET /user/:id` | `POST /user` |
| ----------------- | --------------: | -----------: |
| Dox               | 582,861         | 576,435      |
| Dox server only   | 666,149         | 676,363      |
| Rust<br>hyper | 553,689         | 563,347      |
| Bun               | 488,315         | 496,905      |
| Relic 2           | 432,465         | 376,030      |
| Node              | 268,959         | 291,521      |
| Go                | 229,640         | 232,201      |
| `dart:io`         | 94,084          | 124,623      |

### Why it is fast

The server runs on the thread of the isolate, so a request never waits for another thread to wake up. See [Native server](native-server.md#how-it-works). A profile with `perf` (4 server cores, 64 connections):

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
- 3 rounds on 2026-11-22. In each round, every server runs one time. The
  tables show the median of the 3 rounds.
- Every server has as many workers as server CPUs.
- Peak memory is the peak of the container (all workers).
- Dart 3.13.7, AOT build with `dart build cli` (this is what `dox build`
  does). `dox_core` and `dox_http_native` are the releases of 2026-11-22. Node 26.13, Bun 1.4.5, Go 1.26, Rust 1.99 with hyper 1.
- Relic is `relic` 2.0.0 with `relic_native` 2.0.0, started with `serveNative()`.

## App benchmark

A small real app, the same in each language: `GET /json` returns a map, `GET /db` reads one row by id from Postgres, and `GET /queries?n=20` reads 20 rows one after another. The table has 10,000 rows, and each app uses its database driver with no ORM.

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

The Dox numbers are from 2026-11-16. The other servers are from the run before, on the same Mac.

All three routes at 256 connections, requests per second:

| Server                           | `/json` | `/db`   | `/queries?n=20` | peak MB |
| -------------------------------- | ------: | ------: | --------------: | ------: |
| Dox<br>`dox_postgres_native` | 592,900 | 297,000 | 18,015          | 93      |
| Bun<br>`Bun.sql` | 564,362 | 198,296 | 18,994          | 64      |
| Rust<br>hyper + `tokio-postgres` | 667,718 | 128,065 | 9,312           | 11      |
| Node<br>`node:http` + `pg` | 205,774 | 75,447  | 7,458           | 232     |
| Go<br>`net/http` + pgx | 206,398 | 55,903  | 6,635           | 31      |
| `dart:io`<br>`package:postgres` | 89,480  | 28,598  | 2,269           | 47      |

- On one query per request, Dox is the fastest: 1.5 times Bun.
- On 20 queries per request, Dox and Bun are about the same. Postgres is
  the limit here. Both are about twice as fast as Rust.

The same app on MySQL 8.4 (`dox_mysql_native`). The `dart:io` app has no
MySQL version.

| Server                           | `/json` | `/db`   | `/queries?n=20` | peak MB |
| -------------------------------- | ------: | ------: | --------------: | ------: |
| Dox<br>`dox_mysql_native` | 558,886 | 247,242 | 12,347          | 70      |
| Bun<br>`Bun.sql` | 561,340 | 201,923 | 12,676          | 65      |
| Rust<br>hyper + `mysql_async` | 653,244 | 46,795  | 3,158           | 10      |
| Node<br>`node:http` + `mysql2` | 205,630 | 74,809  | 6,001           | 239     |
| Go<br>`net/http` + `go-sql-driver` | 211,713 | 55,322  | 5,520           | 27      |

How it was run: the same rig as the [benchmark](#how-it-was-run) above.
The server gets 2 CPUs, the database gets 2 CPUs and wrk gets the other 4.
Each server has 4 database connections per core, 8 in total. One run of 15
seconds per route. The Postgres Dox row was measured again on 2026-11-16 (same Mac, a new Docker VM). The other servers and the MySQL table are from the run before.

## Database drivers

One find-by-id query, AOT build (`dart build cli`), database on the same machine (Apple M-series), one isolate:

| Database | One query at a time | Many queries in flight | App CPU time per query |
| --- | --- | --- | --- |
| Postgres 14<br>4 connections | 60 µs | 12.5 µs each<br>64 in flight | |
| MySQL 8.4<br>10 connections | 67 µs | 11 µs each<br>32 in flight | 13.5 µs |
| MariaDB 11<br>10 connections | 63 µs | 9.7 µs each<br>32 in flight | 12.4 µs |

The CPU time counts the Dart thread and the Rust thread. For MySQL, it is about 75,000 queries per second on one core. Many requests at the same time, like in a web server, get the most out of the driver.

## Dart VM flags

A bigger young generation (`DART_VM_OPTIONS=--new_gen_semi_max_size=64` or `128`) did not give a better p99 in 5 runs, so Dox sets no VM flags. The AOT binary of `dox build` reads `DART_VM_OPTIONS`, so you can try your own.

## Next steps

- [Performance mistakes](performance-mistakes.md): the code that makes an app slow.
- [Isolate](isolate.md): how Dox uses the CPU cores.

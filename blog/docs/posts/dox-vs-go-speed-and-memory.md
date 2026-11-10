---
date:
  created: 2026-11-10
authors:
  - dox
categories:
  - Performance
tags:
  - performance
  - benchmark
  - memory
  - go
slug: dox-vs-go-speed-and-memory
---

# Dox vs Go: speed and memory

In our published benchmark on 2 CPU cores, a Dox app handled 2× to 4.8× the requests per second of a Go app.
Go used less memory once a database was added.

<!-- more -->

## The short answer

Requests per second at 256 connections. The last column shows how many times the requests of Go that Dox handled:

| Test | Dox | Go | Dox handles |
| --- | ---: | ---: | ---: |
| Plain HTTP, `GET /` | 638,067 | 242,043 | **2.6×** |
| Plain HTTP, `GET /user/:id` | 572,658 | 230,845 | **2.5×** |
| Plain HTTP, `POST /user` | 545,986 | 231,050 | **2.4×** |
| JSON, `GET /json` | 555,216 | 206,398 | **2.7×** |
| One row from Postgres, `GET /db` | 266,432 | 55,903 | **4.8×** |
| 20 rows from Postgres, `GET /queries?n=20` | 17,772 | 6,635 | **2.7×** |
| One row from MySQL, `GET /db` | 247,242 | 55,322 | **4.5×** |
| 20 rows from MySQL, `GET /queries?n=20` | 12,347 | 5,520 | **2.2×** |

The smallest gap is 2×, on `GET /` at 64 connections.
The JSON row is from the Postgres run.

This post compares Dox with Go only.
The full tables also have other servers. You can find them, and the full method, on the [Performance](/latest/digging-deeper/performance/) page.
Every number here comes from that page.

## How it was measured

- Docker on an Apple M2, with 8 CPUs in the Docker VM (`linux/arm64`).
- The server gets 2 CPUs. The load tool (wrk 4.1) runs on other CPUs.
- One server runs at a time. Connections use keep-alive.
- Each server has one worker per core. Dox has one isolate per core. Go is one process with `GOMAXPROCS=2`.
- Dox is an AOT build (`dox build`) with Dart 3.13.6. Go is version 1.26.
- The Go app uses the standard library server, `net/http`. We did not test other Go servers or frameworks.
- 5 seconds of warm-up, then 15 seconds per route.
- **Peak memory is the peak of the whole container.**

## Plain HTTP

The test follows the rules of [the-benchmarker/web-frameworks](https://github.com/the-benchmarker/web-frameworks).
Dox is a full Dox app with three routes. Go uses `net/http` with `http.ServeMux`.

<div class="dox-bench dox-bench--simple" markdown>

<p class="dox-bench__title">Requests per second on 2 cores</p>
<p class="dox-bench__sub"><code>GET /</code>, 256 connections. Higher is better.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>full app</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">638,067<span class="dox-bench__vs">fastest</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 37.9%"></span></span>
    <span class="dox-bench__num">242,043<span class="dox-bench__vs">2.6× slower</span></span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Go 1.26 · Dart 3.13 · 2 cores · 256 connections · wrk</span></p>

</div>

<div class="dox-bench dox-bench--simple" markdown>

<p class="dox-bench__title">Peak memory on 2 cores</p>
<p class="dox-bench__sub"><code>GET /</code>, 256 connections. Peak memory of the container, lower is better.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">peak</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>full app</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 52.8%"></span></span>
    <span class="dox-bench__num">19 MB<span class="dox-bench__vs">lowest</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">36 MB<span class="dox-bench__vs">1.9× more</span></span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Go 1.26 · Dart 3.13 · 2 cores · 256 connections · wrk</span></p>

</div>

`GET /`, requests per second:

| Server | 64 connections | 256 connections | 512 connections | p99 at 256 | peak MB |
| --- | ---: | ---: | ---: | ---: | ---: |
| Dox | 494,223 | 638,067 | 612,032 | 0.74 ms | 19 |
| Go (`net/http`) | 248,951 | 242,043 | 232,687 | 3.27 ms | 36 |

The other two routes, at 256 connections:

| Server | `GET /user/:id` | `POST /user` |
| --- | ---: | ---: |
| Dox | 572,658 | 545,986 |
| Go | 230,845 | 231,050 |

Dox handled 2× the requests of Go at 64 connections, and 2.6× at 256 and 512 connections.
On the other two routes it handled 2.5× and 2.4×.
Its peak memory was 19 MB. Go's peak was 36 MB.
Both are small.

## A small app with a database

This test is closer to a real app:

- `GET /json` returns a map as JSON.
- `GET /db` reads one row by id.
- `GET /queries?n=20` reads 20 rows, one after another.

Each app uses its database driver directly, with no ORM.
Dox uses `dox_postgres_native` or `dox_mysql_native`. Go uses pgx or `go-sql-driver`.
The server gets 2 CPUs and the database gets 2 CPUs.
Each server has 8 database connections in total.
There was one run of 15 seconds per route.

<div class="dox-bench dox-bench--simple" markdown>

<p class="dox-bench__title">Read one row on 2 cores</p>
<p class="dox-bench__sub"><code>GET /db</code> on Postgres 18, 256 connections. Higher is better.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>dox_postgres_native</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">266,432<span class="dox-bench__vs">fastest</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 21%"></span></span>
    <span class="dox-bench__num">55,903<span class="dox-bench__vs">4.8× slower</span></span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Go 1.26 · Dart 3.13 · Postgres 18 · 2 cores · 256 connections · wrk</span></p>

</div>

<div class="dox-bench dox-bench--simple" markdown>

<p class="dox-bench__title">Peak memory with Postgres on 2 cores</p>
<p class="dox-bench__sub">256 connections. Peak memory of the container, lower is better.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">peak</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Go</strong><span>pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 29.2%"></span></span>
    <span class="dox-bench__num">31 MB<span class="dox-bench__vs">lowest</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Dox</strong><span>dox_postgres_native</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">106 MB<span class="dox-bench__vs">3.4× more</span></span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Go 1.26 · Dart 3.13 · Postgres 18 · 2 cores · 256 connections · wrk</span></p>

</div>

Postgres 18, requests per second at 256 connections:

| Server | `/json` | `/db` | `/queries?n=20` | peak MB |
| --- | ---: | ---: | ---: | ---: |
| Dox (`dox_postgres_native`) | 555,216 | 266,432 | 17,772 | 106 |
| Go (`net/http` + pgx) | 206,398 | 55,903 | 6,635 | 31 |

MySQL 8.4, requests per second at 256 connections:

| Server | `/json` | `/db` | `/queries?n=20` | peak MB |
| --- | ---: | ---: | ---: | ---: |
| Dox (`dox_mysql_native`) | 558,886 | 247,242 | 12,347 | 70 |
| Go (`net/http` + `go-sql-driver`) | 211,713 | 55,322 | 5,520 | 27 |

On `/db` with Postgres, the p99 was 1.8 ms for Dox and 6.3 ms for Go.

Three things to see here:

- Dox handled more requests on every route. The gap is largest on `/db`: 4.8× with Postgres and 4.5× with MySQL.
- On `/json` it handled 2.7×. On 20 queries per request it handled 2.7× with Postgres and 2.2× with MySQL.
- Go used less memory. Its peak was 31 MB with Postgres and 27 MB with MySQL. The peak of Dox was 106 MB and 70 MB.

## Why the numbers differ

We did not profile the Go app.
So we can not say where its time goes.
But the two servers are built in different ways:

- **How a request runs.** In Dox, the native HTTP server runs on the thread of the isolate. One call writes the answers, reads the sockets and parses the new requests. Under load, no other thread is involved. In Go, `net/http` starts one goroutine per connection, and the Go scheduler runs the goroutines on the threads.
- **How a query is sent.** The Dox drivers send many queries down one connection at once (pipelining). In the Go app, each query takes one connection from the pool and waits for its answer. With 8 connections, at most 8 queries run at the same time.
- **Memory.** Both are one process with a compiled binary and no JIT compiler. This helps both stay small on plain HTTP. We did not measure why Dox needs more memory than Go when a database is added.

[What makes Dox fast](what-makes-dox-fast.md) explains the Dox side in more detail.

## Measure your own app

These numbers come from one machine and very small apps.
Your app is different. It has more routes, more data and its own code.
A real app spends most of its time on the database, JSON and your own logic.
So the gap in your app can be smaller or larger.

Before you choose, build your app with `dox build` and measure it on your own server.
The [Performance](/latest/digging-deeper/performance/) page shows how we ran the tests, so you can run them the same way.

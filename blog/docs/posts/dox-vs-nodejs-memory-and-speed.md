---
date:
  created: 2026-11-09
authors:
  - dox
categories:
  - Performance
tags:
  - performance
  - benchmark
  - memory
  - node
slug: dox-vs-nodejs-memory-and-speed
---

# Dox vs Node.js: memory and speed

In our published benchmark on 2 CPU cores, a Dox app served more requests per second than a Node.js app and used much less memory.

<!-- more -->

This post compares Dox with Node.js only.
The full tables also have other servers. You can find them, and the full method, on the [Performance](/latest/digging-deeper/performance/) page.
Every number here comes from that page.

## How it was measured

- Docker on an Apple M2, with 8 CPUs in the Docker VM (`linux/arm64`).
- The server gets 2 CPUs. The load tool (wrk 4.1) runs on other CPUs.
- One server runs at a time. Connections use keep-alive.
- Each server has one worker per core. Dox has one isolate per core. Node has one process per core (`node:cluster`).
- Dox is an AOT build (`dox build`) with Dart 3.13.6. Node is version 26.12.
- 5 seconds of warm-up, then 15 seconds per route.
- **Peak memory is the peak of the whole container.** It counts every process in the container. For Node, that includes the cluster primary process, which does not serve requests.

## Plain HTTP

The test follows the rules of [the-benchmarker/web-frameworks](https://github.com/the-benchmarker/web-frameworks).
Dox is a full Dox app with three routes. Node uses `node:http`.

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
    <span class="dox-bench__name"><strong>Node</strong><span>node:http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 45%"></span></span>
    <span class="dox-bench__num">286,847<span class="dox-bench__vs">2.2× slower</span></span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Node 26 · Dart 3.13 · 2 cores · 256 connections · wrk</span></p>

</div>

<div class="dox-bench dox-bench--simple" markdown>

<p class="dox-bench__title">Peak memory on 2 cores</p>
<p class="dox-bench__sub"><code>GET /</code>, 256 connections. Peak memory of the container, lower is better.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">peak</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>full app</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 9.5%"></span></span>
    <span class="dox-bench__num">19 MB<span class="dox-bench__vs">lowest</span></span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>node:http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">200 MB<span class="dox-bench__vs">10.5× more</span></span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Node 26 · Dart 3.13 · 2 cores · 256 connections · wrk</span></p>

</div>

`GET /`, requests per second:

| Server | 64 connections | 256 connections | 512 connections | p99 at 256 | peak MB |
| --- | ---: | ---: | ---: | ---: | ---: |
| Dox | 494,223 | 638,067 | 612,032 | 0.74 ms | 19 |
| Node (`node:http`) | 252,866 | 286,847 | 296,257 | 1.70 ms | 200 |

The other two routes, at 256 connections:

| Server | `GET /user/:id` | `POST /user` |
| --- | ---: | ---: |
| Dox | 572,658 | 545,986 |
| Node | 274,067 | 301,084 |

At 256 connections, Dox served about 2.2 times more requests than Node on `GET /`.
Its peak memory was 19 MB. Node's peak was 200 MB.

## A small app with a database

This test is closer to a real app:

- `GET /json` returns a map as JSON.
- `GET /db` reads one row by id.
- `GET /queries?n=20` reads 20 rows, one after another.

Each app uses its database driver directly, with no ORM.
Dox uses `dox_postgres_native` or `dox_mysql_native`. Node uses `pg` or `mysql2`.
The server gets 2 CPUs and the database gets 2 CPUs.
Each server has 4 database connections per core, so 8 in total.
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
    <span class="dox-bench__name"><strong>Node</strong><span>pg</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 28.3%"></span></span>
    <span class="dox-bench__num">75,447<span class="dox-bench__vs">3.5× slower</span></span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Node 26 · Dart 3.13 · Postgres 18 · 2 cores · 256 connections · wrk</span></p>

</div>

Postgres 18, requests per second at 256 connections:

| Server | `/json` | `/db` | `/queries?n=20` | peak MB |
| --- | ---: | ---: | ---: | ---: |
| Dox (`dox_postgres_native`) | 555,216 | 266,432 | 17,772 | 106 |
| Node (`node:http` + `pg`) | 205,774 | 75,447 | 7,458 | 232 |

MySQL 8.4, requests per second at 256 connections:

| Server | `/json` | `/db` | `/queries?n=20` | peak MB |
| --- | ---: | ---: | ---: | ---: |
| Dox (`dox_mysql_native`) | 558,886 | 247,242 | 12,347 | 70 |
| Node (`node:http` + `mysql2`) | 205,630 | 74,809 | 6,001 | 239 |

On `/db` with Postgres, the p99 was 1.8 ms for Dox and 4.1 ms for Node.

Two things to see here:

- Dox uses more memory with a database than without one: 106 MB with Postgres and 70 MB with MySQL, against 19 MB for plain HTTP.
- Node also uses more memory, and stays at or above 200 MB in all three tests.

## Why Dox uses less memory

We did not measure where each megabyte goes.
But these design choices make a difference:

- **One process.** Dox runs one process with one isolate per core. The isolates share one compiled program. The Node app runs one process per core plus a primary process, and each one loads its own JavaScript engine and its own copy of the app.
- **No JIT compiler.** `dox build` makes an AOT binary, so no compiler runs next to your app. Node compiles JavaScript while the app runs.
- **Socket work outside the Dart heap.** The native HTTP server reads the sockets and parses HTTP in native code.
- **One database pool.** All isolates share one pool for the whole process.

[What makes Dox fast](what-makes-dox-fast.md) explains each of these in more detail.

## Measure your own app

These numbers come from one machine and very small apps.
Your app is different. It has more routes, more data and its own code.
A real app spends most of its time on the database, JSON and your own logic.
So the gap in your app can be smaller or larger.

Before you choose, build your app with `dox build` and measure it on your own server.
The [Performance](/latest/digging-deeper/performance/) page shows how we ran the tests, so you can run them the same way.

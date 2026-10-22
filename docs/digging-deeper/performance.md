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

### 4 cores

| Server                          | req/s   | p99 ms | CPU % | peak MB |
| ------------------------------- | ------: | -----: | ----: | ------: |
| Dox, native server, 4 isolates  | 337,486 | 0.67   | 306   | 18      |
| Dox, `dart:io` server, 4 isolates | 142,334 | 3.45 | 345   | 25      |
| Bun 1.4.3                       | 184,844 | 1.07   | 101   | 15      |
| Node 24.22.0                    | 80,726  | 2.26   | 101   | 55      |
| Go 1.27.3 (`net/http`)          | 336,274 | 2.57   | 334   | 16      |

Bun and Node use one thread, so more cores do not help them. Dox runs one
isolate per core and shares the port (`SO_REUSEPORT`). On 4 cores Dox is
1.8x Bun at 100 connections and 2.3x Bun at 256 connections
(415,537 req/s). It is as fast as Go. Here wrk was close to its own limit
(about 280-330% of its 400%), so Dox may go higher on a bigger machine.

With pipelining (16 requests per batch), Dox native gives 153k req/s on
1 core (Bun: 200k) and 400-483k req/s on 4 cores (Bun: 199k).

How it was run:

- Docker on an Apple M2 (8 CPUs in the Docker VM), `linux/arm64`.
- The server and wrk run in two containers, pinned to different CPUs:
  server on CPU 0 (or 0-3), wrk on CPUs 2-7 (or 4-7).
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

| Route            | Dox     | Bun     | Go     | `dart:io` |
| ---------------- | ------: | ------: | -----: | --------: |
| /json req/s      | 157,036 | 176,148 | 79,884 | 33,670    |
| /db req/s        | 85,381  | 57,614  | 36,706 | 12,146    |
| /queries req/s   | 9,745   | 10,097  | 3,810  | 966       |
| /db p99 ms       | 5.65    | 6.11    | 14.49  | 47.62     |
| /db peak MB      | 24      | 36      | 18     | 62        |

### 2 cores

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

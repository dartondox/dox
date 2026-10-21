# Performance

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

How it was run: measured with wrk in Docker on an Apple M2 (linux/arm64),
CPU pinned.

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

## Numbers

Measured on a MacBook (Apple M-series, 8 cores), Dart 3.13. The load tool
ran on the same machine, so it took some of the CPU. Treat the numbers as a
comparison, not as a max.

`json` = `GET /json` returning a small map. `param` = `GET /user/{id}`.
64 keep-alive connections, 8 seconds.

| Setup           | Start  | Idle memory | json req/s | param req/s |
| --------------- | ------ | ----------- | ---------- | ----------- |
| JIT, 1 isolate  | 1.0 s  | 388 MB      | 26-28k     | 29k         |
| AOT, 1 isolate  | 0.05 s | 16 MB       | 27-30k     | 26-28k      |
| JIT, 8 isolates | 1.0 s  | 398 MB      | 54-57k     | 52-58k      |
| AOT, 8 isolates | 0.05 s | 16 MB       | 60k        | 56-62k      |

Before and after the changes in this release (AOT):

| Test                         | Before   | After    |
| ---------------------------- | -------- | -------- |
| json, 1 isolate              | 23k/s    | 27-30k/s |
| param, 1 isolate             | 20k/s    | 26-28k/s |
| json, 8 isolates             | 54k/s    | 60k/s    |
| param, 8 isolates            | 52k/s    | 56-62k/s |
| 50 MB upload, peak memory    | 1,100 MB | 72-93 MB |
| 50 MB upload, JIT peak memory| 1,380 MB | 389 MB (= JIT idle) |
| request logs on, req/s cost  | -13%     | -4%      |

For reference, a bare `dart:io` server with the same JSON gives about 44k/s on
one isolate. So Dox adds some cost on top of `dart:io`, and that is the next
place to look.

Run it yourself (from `packages/dox-core`):

```bash
bash benchmark/run.sh          # SECS=10 CONNS=64 N=<cores> to change
```

It needs only Dart and `curl`. It uses a small Dart load tool
(`benchmark/load.dart`), because `wrk` and `oha` are often not installed.

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
- A bigger file is written to a temp file while it arrives. A 50 MB upload
  no longer needs 1 GB of RAM.
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

`LogMiddleware` prints one JSON line per request. Writing to stdout blocks.
Dox now collects log lines and writes them every 20 ms (or every 64 KB) in
one write. If the process is killed hard, the last 20 ms of request logs can
be lost. Errors from `Logger` are still written right away.

Turn `LogMiddleware` off when a proxy already writes access logs.

## What else was fixed on the hot path

- Routes are grouped by method, and each route's regex is built once, not
  on every request.
- Route params are now per request. Before, two requests to the same route
  at the same time could see each other's params.
- The controller's argument types are read once per controller, not three
  times per request.

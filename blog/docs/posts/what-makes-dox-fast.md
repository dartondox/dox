---
date:
  created: 2026-11-09
authors:
  - dox
categories:
  - Performance
tags:
  - performance
  - architecture
slug: what-makes-dox-fast
---

# What makes Dox fast

Dox is fast because your Dart code runs as a compiled binary, the network and database work happens in native code on the same thread, and most of the setup work is done once at build time or at start.

<!-- more -->

Your app is plain Dart: routes, controllers, DTOs, middleware and models.
This post explains what Dox does around that code, one reason at a time.
Each section links to the docs page with the details.

## A compiled binary

`dox build` compiles your app ahead of time (AOT) into a native binary.
The code is machine code before the server starts.
No compiler runs next to your app, and the server needs no Dart SDK.

`dart run` and `dox serve` use the JIT compiler.
They are for development. They use much more memory and start slower.
Always run the AOT binary in production.

See [Deployment](/latest/digging-deeper/deployment/).

## A native HTTP server on the isolate's thread

Every Dox app runs on `dox_http_native`.
It is written in Rust. It owns the sockets and parses HTTP.
Your code still runs in Dart.

The server works in a loop on the isolate's own thread:

1. Dart makes one call into the native code.
2. The native code writes the answers of the last batch, reads the sockets and parses the new requests. It gives them to Dart as one batch.
3. Dart runs your handlers and makes the next call with their answers.

Under load, no other thread is involved.
So a request never waits for another thread to wake up.
A small helper thread only watches the sockets while the isolate is idle.

The server has the same API as the `dart:io` `HttpServer`.
Code written for `dart:io` keeps working.

See [Native server](/latest/digging-deeper/native-server/).

## One isolate per CPU core

Dox starts one isolate per CPU core by default.
Each isolate runs the whole app and its own server on the same port.
The operating system spreads the connections between them.

All isolates live in one process and share the compiled program.
You do not need a process manager to use all cores.

See [Isolate](/latest/digging-deeper/isolate/).

## Keep-alive and pipelining

A connection stays open for the next request (keep-alive).
A client can also send many requests on one connection without waiting for each answer (pipelining).

There are limits, so one client can not fill the memory.
At most 64 requests of one connection wait for an answer.
At most 1 MB of answers waits to be sent.
Then the server stops reading that connection until the answers go out.

See [Native server: limits](/latest/digging-deeper/native-server/#limits).

## Native database drivers

Postgres and MySQL use native drivers: `dox_postgres_native` and `dox_mysql_native`.
Your models and queries stay in Dart. You do not change any config.

- The database work runs on the thread of each isolate, like the HTTP server. There is no extra thread to hand a query to.
- Many queries go down one connection at once (pipelining).
- Dart sends many queries in one call. The results come back together.
- All isolates share one pool. The pool size is for the whole process, so the database gets a known number of connections.

See [Native Postgres driver](/latest/database/postgres-native/), [Native MySQL driver](/latest/database/mysql-native/) and the package READMEs on GitHub:
[dox-postgres-native](https://github.com/dartondox/dox-postgres-native) and
[dox-mysql-native](https://github.com/dartondox/dox-mysql-native).

## Generated code, not reflection

Dox does not use `dart:mirrors`.
Instead, `build_runner` with `dox_builder` writes plain Dart code for you:

- the dependency injection container (`lib/generated/container.g.dart`),
- the list of your `Router` classes, in the same file,
- the DTO checks (a `.dto.g.dart` file next to each DTO),
- the model classes.

The DTO rules, like `@Email()` or `@Min(18)`, become typed Dart code at build time.
They are not rule strings that are read on each request.
This is also what makes the AOT build possible.

See [Dependency injection](/latest/the-basic/dependency-injection/) and [Validation](/latest/the-basic/validation/).

## Work done once, not on each request

When an isolate starts, it does some work once:

- It builds the pattern of each route.
- It reads the parameter types of each controller.
- It groups the routes by HTTP method.

On each request, Dox does less:

- JSON and text responses are encoded once, straight to bytes, with `Content-Length` set.
- `LogMiddleware` collects log lines and writes them in one write every 20 ms (or every 64 KB). In a new project it is off in production.

See [Performance: what Dox does for you](/latest/digging-deeper/performance/#what-dox-does-for-you) and [How Dox works](/latest/concepts/how-dox-works/).

## What Dox does not do

Some choices are left to you on purpose:

- **No VM flags.** Dox never sets Dart VM flags for you. We tried a bigger young generation for a better p99. The change was inside the noise, so there is no flag to set. You can try your own with `DART_VM_OPTIONS`.
- **No gzip in Dart by default.** gzip costs CPU on every response. A proxy like Caddy or nginx does it better. If you have no proxy, `AppConfig(compress: true)` turns it on, and the native server gzips on a helper thread.

See [Performance: Dart VM flags](/latest/digging-deeper/performance/#dart-vm-flags) and [Performance: gzip](/latest/digging-deeper/performance/#gzip).

## A few numbers

On 2 CPU cores, `GET /` with 256 connections, a full Dox app served 638,067 requests per second.
A plain `dart:io` `HttpServer`, with no framework, served 129,796.
In a small app that reads one row from Postgres (`GET /db`), Dox served 266,432 requests per second.

These numbers come from one machine and very small apps.
A real app spends most of its time on the database, JSON and your own code, so the gaps are smaller there.
Measure your own app.
The [Performance](/latest/digging-deeper/performance/) page has the full tables and how they were measured.

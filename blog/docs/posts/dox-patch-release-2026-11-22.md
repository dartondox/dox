---
date:
  created: 2026-11-22
authors:
  - dox
categories:
  - Releases
tags:
  - release
slug: dox-patch-release-2026-11-22
---

# Dox patch release: 22 November 2026

This release is patch versions only. It makes the tail latency lower on servers with 4 or more CPU cores, and it makes routes with params faster. One fix changes the match of two rare routes, so read [Read before you update](#read-before-you-update).

<!-- more -->

> **Key takeaways**
>
> - **Lower tail latency.** On 4 server cores with 64 connections, p99 goes from 2.4 ms to 0.3 ms.
> - **Faster param routes.** A route like `/users/{id}` is matched without a regex. The match goes from 142 ns to 16 ns.
> - **Route parts with text and params.** Routes like `/v{id}/{name}` now give each param its own value.
> - **Easy to update.** Patch versions only. Run `dart pub upgrade`, then check [Read before you update](#read-before-you-update).

## Versions

| Package | New version |
| --- | --- |
| `dox_core` | 3.2.5 |
| `dox_http_native` | 3.2.3 |
| `dox_grpc` | 0.0.2 |

No change: all the other packages, the `dox` CLI and the app template.

## How to update

1. Get the new versions:

    ```bash
    dart pub upgrade
    ```

2. Build or start the app again. The new native library downloads automatically.

3. Read [Read before you update](#read-before-you-update).

There is no API change and no config change.

## Faster

### Lower tail latency on more cores

The HTTP server of Dox runs on native threads, and it gives each request to Dart. Before this release, the server gave its sockets to an idle thread as soon as it sent an answer. Each return to Dart then cost 2 thread wake-ups. On a server with idle CPU cores, these wake-ups made some requests wait.

Now the server waits up to 1 ms for the next requests in the same call, after it sends a whole answer and no request is open.

| 4 server cores | p99 before | p99 now |
| --- | --- | --- |
| 64 connections | 2.4 ms | 0.3 ms |
| 256 connections | 2.8 ms | approximately 1 ms |

With 64 connections, the server also does 1% to 6% more requests a second. On 2 server cores, the numbers do not change.

There is no wait while a request or a streamed answer is open. A WebSocket message and a part of a streamed answer do not start a wait.

### Param routes without a regex

A route with params like `/users/{id}` is now matched without a regex, when each part of its path is plain text or one whole param. The match goes from 142 ns to 16 ns. On 2 server cores, `GET /user/{id}` does 2% to 4% more requests a second.

Routes with `{id?}`, `{path*}` or `Route.where` use the regex, as before. The matched routes and the param values do not change.

## Fixes

- **Route parts with text and params.** A route part can have text and params together, like `/v{id}/{name}`, `/v{id}` and `/{a}-{b}`. Before, `/v{id}/{name}` gave the value of `id` for `req.param['name']`. Now each param has its own name and value. `Route.url` also fills the params of such a route.
- **Gzip answers.** A gzip answer sometimes did not go out until other traffic came. Now the server sends the answer in the same call.
- **gRPC install.** The router file that `dox grpc:install` writes no longer tells you to keep `Route.middleware` out. A service can go inside `Route.middleware`, after the health service.

## Read before you update

- **Two rare route matches change.** Examine your routes for a part that has text and a param together.
    - `/v{id}` now matches `/v5`. Before, it matched only the text `/v{id}`.
    - `/{a}-{b}` now matches `/x-y` but not `/x`. Before, it was one param with the name `a}-{b`.
- **`dox_core` 3.2.5 needs `dox_http_native` 3.2.3.** `dart pub upgrade` gets it. The ABI version stays 10.
- **Timers.** Other work of the isolate, for example a timer, can start up to 2 ms later.

Full list: the CHANGELOG of each package.

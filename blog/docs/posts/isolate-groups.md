---
date:
  created: 2026-11-27
authors:
  - dox
categories:
  - Performance
tags:
  - release
  - performance
  - memory
slug: isolate-groups
---

# Isolate groups: each isolate gets its own memory

Dox can now give each server isolate its own heap and its own garbage collector. One flag turns it on. In our test, the same app did 9% more requests a second, and 18% more with three settings of the Dart VM. The flag is off by default, so an app that does not turn it on works the same as before.

<!-- more -->

> **Key takeaways**
>
> - **One flag.** Set `CoreFlags(isolateGroups: true)` in the app config.
> - **A garbage collection in one isolate does not stop the others.** Each isolate has its own heap.
> - **No limit of 8 isolates.** By default, the Dart VM runs only 8 isolates of one group at the same time.
> - **More requests and a lower P99.** `GET /json` on 4 server cores: 9% more requests a second, and a P99 of 4.55 ms, down from 6.35 ms.
> - **`main()` runs in each isolate.** Use `Dox().isPrimary` for work that must run only one time.

## Why isolates shared memory

Dox runs one isolate for each CPU core. Until now, all these isolates were in one isolate group of the Dart VM. One group has one heap and one garbage collector. This has two effects:

- When the garbage collector moves objects, all isolates of the group wait.
- The VM runs a maximum of 8 isolates of one group at the same time. A server with more than 8 CPU cores used only approximately 8 of them.

With isolate groups, each isolate is in its own group. Thus each isolate has its own heap, and a pause in one isolate does not stop the others. The limit of 8 does not apply.

## Turn it on

Set the flag in the app config:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  appKey: env.appKey,
  flags: CoreFlags(isolateGroups: env.appEnv == 'production'),
  // ...
);
```

Turn it on only in production. In development, the app starts slower and uses more memory with this flag, and one group is sufficient there.

`CoreFlags.all()` does not turn on this flag.

## What changes for your app

Each isolate now runs `main()` of `bin/server.dart` from the start. Most apps need no change:

- **Migrations.** The first isolate runs them before the other isolates start. The other isolates find none to run.
- **Work that must run one time.** Put it behind `Dox().isPrimary`. It is true only in the first isolate.
- **Settings.** Each isolate builds the config again. Read your settings and the app key from the env, not from command line arguments.

```dart title="bin/server.dart"
if (Dox().isPrimary) {
  await warmUpReports();
}
```

`IsolateBus`, the rate limit and `Dox().compute` continue to work. `Dox().compute` has one pool of workers in each isolate.

## Build

On Linux, the bundle of `dox build` works with no change. On macOS, also make a snapshot file with the name of the executable and `.aot`:

```bash
dart compile aot-snapshot bin/server.dart -o build/bundle/bin/server.aot
```

If Dox finds no file to start, it prints one warning and the isolates share memory, as before.

## Give each isolate more memory

The Dart VM keeps free memory pages for one isolate only. To keep them for all isolates, set 32 MB for each isolate:

```dockerfile
# 4 isolates: 4 x 32 = 128
ENV DART_VM_OPTIONS=--new_gen_semi_max_size=128,--new_gen_semi_initial_size=32,--new_gen_garbage_threshold=0
```

The app is faster and uses more memory, approximately 30 MB for each isolate.

## What we measured

We ran the same Docker image with the flag off and with the flag on. The server had 4 CPU cores. The load was `GET /json` (50 objects) with `wrk` and 256 connections for 15 seconds. Each number is the median of 3 rounds.

| | Requests a second | P50 | P99 | Memory |
| --- | --- | --- | --- | --- |
| Flag off | 137,253 | 1.75 ms | 6.35 ms | 25 MB |
| Flag on | 149,925 | 1.59 ms | 4.55 ms | 28 MB |
| Flag on, with the VM settings | 161,745 | 1.51 ms | 3.16 ms | 139 MB |

With 2 server cores, the result was almost the same: 9% more requests a second with the flag, and 18% more with the VM settings.

Three limits of this test:

- The test ran on Linux in Docker on a Mac with 8 cores. Your numbers will be different.
- A route with an empty body (`GET /`) got only 1% to 3% more. It makes little garbage, so the garbage collector has little work.
- We did not measure a server with more than 8 cores.

## When to use it

Turn on the flag when one of these is true:

- Your server has more than 8 CPU cores.
- Your routes make many objects, for example big JSON responses.
- A low P99 is important for your app.

Keep it off for a small server with little memory. The default continues to work, and Dox shows a warning at the start if the app has more isolates than the VM runs.

For the full guide, read [Give each isolate its own memory](/latest/digging-deeper/deployment/#give-each-isolate-its-own-memory).

## Versions

| Package | New version |
| --- | --- |
| `dox_core` | 3.2.6 |

To update an app, run `dart pub upgrade`. Isolate groups stay off until you turn them on.

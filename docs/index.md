---
title: Getting Started
description: Dox is a fast web backend framework for Dart, like Laravel. Routing, an ORM, migrations, typed validation, auth and a CLI, on a Rust HTTP server.
hide:
  - toc
---

<div class="dox-hero" markdown>

<div class="dox-hero__text" markdown>

<img class="dox-hero__mascot" src="assets/mascot.png" alt="Doxie, the Dox mascot" width="140" height="137">

# Fast backends<br>in Dart

<p class="dox-hero__lead"><strong>Write in Dart. Serve with Rust.</strong></p>

<p class="dox-hero__lead">
Dox is a web backend framework for Dart, like Laravel.
Routing, an ORM, migrations, validation, auth and a CLI come in one place.
It runs one isolate per CPU core and builds to a small native binary.
</p>

<p class="dox-hero__actions" markdown>
[Build your first API](tutorial/index.md){ .md-button .md-button--primary }
[GitHub](https://github.com/dartondox/dox){ .md-button }
</p>

</div>

<div class="dox-hero__code" markdown>

```dart
Route.get('/blogs', BlogController.index); // (1)!

enum Status { active, draft }

@Dto() // (2)!
class BlogFilter {
  final Status status; // ?status=active, else 422
  const BlogFilter({required this.status});
  static const DtoSchema<BlogFilter> schema =
      $BlogFilterDto; // (3)!
}

class BlogController {
  static Future<List<Blog>> index(
    BlogFilter query, // (4)!
  ) async {
    return Blog()
        .where('status', query.status.name)
        .get(); // (5)!
  }
}
```

1.  A route points at a static method. No reflection, no controller registry.
2.  `@Dto()` marks an input class. `build_runner` generates the checks from the fields and their types.
3.  The generated schema. The same schema feeds the OpenAPI docs.
4.  Ask for the DTO as a parameter. Dox reads the query (or the body), checks it, and gives you a typed object. Bad input gets a `422` before your code runs.
5.  The ORM. The same code runs on Postgres, MySQL and SQLite. Postgres and MySQL use native Rust drivers.

</div>

</div>

## How fast

<div class="dox-bench" markdown>

<p class="dox-bench__title">1.5× Bun. 2.3× Go. 7× plain Dart.</p>
<p class="dox-bench__sub">A real route: read one row from Postgres and return JSON (<code>GET /db</code>). Requests per second on one CPU core, higher is better.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>native server + driver</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">85,381<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">5.7 ms</span>
    <span class="dox-bench__ram">24 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.serve + Bun.sql</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 67.5%"></span></span>
    <span class="dox-bench__num">57,614<span class="dox-bench__vs">1.5× slower</span></span>
    <span class="dox-bench__p99">6.1 ms</span>
    <span class="dox-bench__ram">36 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http + pgx</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 43%"></span></span>
    <span class="dox-bench__num">36,706<span class="dox-bench__vs">2.3× slower</span></span>
    <span class="dox-bench__p99">14.5 ms</span>
    <span class="dox-bench__ram">18 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>+ package:postgres</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 14.2%"></span></span>
    <span class="dox-bench__num">12,146<span class="dox-bench__vs">7× slower</span></span>
    <span class="dox-bench__p99">47.6 ms</span>
    <span class="dox-bench__ram">62 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox 3.0.0-alpha.3 · Bun 1.4 · Go 1.27 · Dart 3.13 · Postgres 18 · 256 connections · wrk · median of 3 runs</span><a href="digging-deeper/performance/#app-benchmark">All results</a></p>

</div>

Dox also has the lowest p99 (the slowest 1% of requests). Your code is plain
Dart. The speed comes from the Rust HTTP server and database drivers.
Without a database (`GET /json`), Bun is faster.
See [Performance](digging-deeper/performance.md) for every route.

!!! warning "You are reading the 3.x docs (release candidate)"
    `3.0.0-rc.x` is a release candidate. Small things can still change before the stable release.

## Run it in two minutes

You need [Dart](https://dart.dev/get-dart) 3.13 or newer. Nothing else: the
starter project uses SQLite, so there is no database to install.

```bash
dart pub global activate dox ^3.0.0-rc   # install the CLI
dox create my_app                            # download the starter project
cd my_app
dart pub get
dox s                                        # start the server
```

Open a second terminal and call the first route:

```bash
curl localhost:3000/ping
```

```text
pong
```

That is a Dox app. Keep going with the [tutorial](tutorial/index.md): it adds a
model, a database table, validation, login and a Docker image, one short step
at a time.

!!! note "The CLI is not found?"
    `dart pub global activate` puts `dox` in `$HOME/.pub-cache/bin`.
    Add that folder to your `PATH`. See [Installation](getting-started/installation.md).

## Pick your path

| You are... | Start here | Then |
| --- | --- | --- |
| New to Dox | [Tutorial: build a blog API](tutorial/index.md) | [Routing](the-basic/routing.md), [Request](the-basic/request.md), [Validation](the-basic/validation.md) |
| Coming from Laravel | [Coming from Laravel](concepts/coming-from-laravel.md) | [How Dox works](concepts/how-dox-works.md) |
| Looking for one answer | [Guides](guides/index.md) (uploads, auth, Docker, pagination...) | [Reference](reference/index.md) |
| Going to production | [Deployment](digging-deeper/deployment.md) | [Docker](guides/docker.md), [Troubleshooting](reference/troubleshooting.md) |

## What you get

<div class="grid cards" markdown>

-   :material-lightning-bolt: **Fast by default**

    A Rust HTTP server, one isolate per CPU core and streamed bodies.
    `dox build` makes one native binary. See [Performance](digging-deeper/performance.md).

-   :material-database-outline: **ORM and query builder**

    Models, relations, migrations and transactions for Postgres, MySQL/MariaDB and SQLite.
    Postgres and MySQL use native Rust drivers. See [Database](database/index.md).

-   :material-check-decagram-outline: **Typed validation**

    Write a `@Dto` class. Dox checks the input and gives your controller a typed object.
    See [Validation](the-basic/validation.md).

-   :material-file-document-outline: **OpenAPI**

    OpenAPI 3.1 docs and a Scalar docs page, made from your routes and DTOs.
    See [`dox_openapi`](packages/openapi.md).

-   :material-folder-outline: **File storage**

    Local disk and S3 behind one API, with signed URLs. See [`dox_storage`](packages/storage.md).

-   :material-cached: **Cache**

    Memory, file and Redis cache with tags and locks. See [`dox_cache`](packages/cache.md).

-   :material-access-point: **Real time**

    [Socket.IO](packages/socketio.md), with Redis for many servers.

-   :material-shield-lock-outline: **Security**

    JWT [authentication](security/authentication.md), [CORS](security/cors.md),
    [encryption](security/encryption.md) and [hashing](security/hashing.md).

-   :material-console: **CLI**

    Create projects, controllers, models and migrations. Run, build and migrate.
    See [CLI reference](reference/cli.md).

</div>

## Get help

- Found a bug or have a question? Open an [issue on GitHub](https://github.com/dartondox/dox/issues).
- Using an AI assistant? Give it [llms-full.txt](https://dartondox.dev/latest/llms-full.txt): all of these docs as one plain text file. [llms.txt](https://dartondox.dev/latest/llms.txt) is the page list.
- Want to help? Read [Contribute](community/contribute.md).

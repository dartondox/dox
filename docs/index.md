---
title: Getting Started
description: Dox is a fast web backend framework for Dart. Routing, an ORM, migrations, typed validation, auth and a CLI, on a native HTTP server.
hide:
  - toc
---

<div class="dox-hero" markdown>

<div class="dox-hero__text" markdown>

<img class="dox-hero__mascot" src="assets/mascot.png" alt="Doxie, the Dox mascot" width="140" height="137">

# Fast backends<br>in Dart

<p class="dox-hero__lead"><strong>Everything your Dart backend needs.</strong></p>

<p class="dox-hero__lead">
Dox is a web backend framework for Dart.
Routing, an ORM, migrations, validation, auth and a CLI come in one place.
It runs one isolate per CPU core and builds to a small native binary.
</p>

<p class="dox-hero__actions" markdown>
[Build your first API](tutorial/index.md){ .md-button .md-button--primary }
[GitHub](https://github.com/dartondox/dox){ .md-button }
[Blog](/blog/){ .md-button }
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
5.  The ORM. The same code runs on Postgres, MySQL and SQLite. Postgres and MySQL use native drivers.

</div>

</div>

## How fast

<div class="dox-bench" markdown>

<p class="dox-bench__title">Ahead of Rust hyper. 1.3× Bun. 2.2× Node. 4.9× plain Dart.</p>
<p class="dox-bench__sub">A full Dox app answers <code>GET /</code>, with the rules of <a href="https://github.com/the-benchmarker/web-frameworks">the-benchmarker</a>. Requests per second on two CPU cores, higher is better.</p>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>native server</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">638,067<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">0.7 ms</span>
    <span class="dox-bench__ram">19 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>hyper</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 91.8%"></span></span>
    <span class="dox-bench__num">585,658<span class="dox-bench__vs">1.09× slower</span></span>
    <span class="dox-bench__p99">0.7 ms</span>
    <span class="dox-bench__ram">13 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.serve</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 78.6%"></span></span>
    <span class="dox-bench__num">501,529<span class="dox-bench__vs">1.27× slower</span></span>
    <span class="dox-bench__p99">1.0 ms</span>
    <span class="dox-bench__ram">40 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>node:http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 45%"></span></span>
    <span class="dox-bench__num">286,847<span class="dox-bench__vs">2.2× slower</span></span>
    <span class="dox-bench__p99">1.7 ms</span>
    <span class="dox-bench__ram">200 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 37.9%"></span></span>
    <span class="dox-bench__num">242,043<span class="dox-bench__vs">2.6× slower</span></span>
    <span class="dox-bench__p99">3.3 ms</span>
    <span class="dox-bench__ram">36 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>HttpServer</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 20.3%"></span></span>
    <span class="dox-bench__num">129,796<span class="dox-bench__vs">4.9× slower</span></span>
    <span class="dox-bench__p99">3.8 ms</span>
    <span class="dox-bench__ram">75 MB</span>
  </div>
</div>

<p class="dox-bench__foot"><span>Dox · Rust 1.99 · Bun 1.4 · Node 26 · Go 1.26 · Dart 3.13 · 2 cores · 256 connections · wrk</span><a href="digging-deeper/performance/#benchmark">All results</a></p>

</div>

Your code is plain Dart. The speed comes from the native server: it runs
on the isolate's own thread, so a request never waits for another thread.
See [Performance](digging-deeper/performance.md) for every route and how
it was run.

## Run it in two minutes

You need [Dart](https://dart.dev/get-dart) 3.13 or newer. Nothing else: the
starter project uses SQLite, so there is no database to install.

```bash
dart pub global activate dox             # install the CLI
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

    A native HTTP server, one isolate per CPU core and streamed bodies.
    `dox build` makes one native binary. See [Performance](digging-deeper/performance.md).

-   :material-database-outline: **ORM and query builder**

    Models, relations, migrations and transactions for Postgres, MySQL/MariaDB and SQLite.
    Postgres and MySQL use native drivers. See [Database](database/index.md).

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
- Using an AI assistant? Give it [llms-full.txt](https://dartondox.dev/llms-full.txt): all of these docs as one plain text file. [llms.txt](https://dartondox.dev/llms.txt) is the page list.
- Want to help? Read [Contribute](community/contribute.md).

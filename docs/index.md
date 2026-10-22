---
title: Getting Started
hide:
  - toc
---

<div class="dox-hero" markdown>

<div class="dox-hero__text" markdown>

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
5.  The ORM. The same code runs on Postgres, MySQL and SQLite, through native Rust drivers.

</div>

</div>

!!! warning "You are reading the 3.x docs (alpha)"
    `3.0.0-alpha.4` is a preview. Things can still change before the stable release.

## Run it in two minutes

You need [Dart](https://dart.dev/get-dart) 3.13 or newer. Nothing else: the
starter project uses SQLite, so there is no database to install.

```bash
dart pub global activate dox 3.0.0-alpha.4   # install the CLI
dox create my_app                            # download the starter project
cd my_app
dart pub get
cp .env.example .env
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
    Add that folder to your `PATH`. See [Installation](the-basic/installation.md).

## Pick your path

| You are... | Start here | Then |
| --- | --- | --- |
| New to Dox | [Tutorial: build a blog API](tutorial/index.md) | [Routing](the-basic/routing.md), [Request](the-basic/request.md), [Validation](the-basic/validation.md) |
| Coming from Laravel | [Coming from Laravel](concepts/coming-from-laravel.md) | [How Dox works](concepts/how-dox-works.md) |
| Looking for one answer | [Guides](guides/index.md) (uploads, auth, Docker, pagination...) | [Reference](reference/index.md) |
| Going to production | [Deployment](digging-deeper/deployment.md) | [Docker](guides/docker.md), [Troubleshooting](reference/troubleshooting.md) |

## How fast

A small app that reads one row from Postgres per request. One CPU core,
256 connections, requests per second. Higher is better.

| Server | `GET /db` req/s | `GET /json` req/s | Peak RAM |
| --- | ---: | ---: | ---: |
| **Dox** 3.0.0-alpha.3 (native server, native driver) | **85,381** | 157,036 | 24 MB |
| Bun 1.4 (`Bun.serve` + `Bun.sql`) | 57,614 | 176,148 | 36 MB |
| Go 1.27 (`net/http` + pgx) | 36,706 | 79,884 | 18 MB |
| `dart:io` + `package:postgres` | 12,146 | 33,670 | 62 MB |

Dox is the same Dart code on every row. The speed comes from the Rust HTTP
server and the Rust database drivers that Dox uses by default.
See [Performance](digging-deeper/performance.md) for the full tables, 2 cores,
and how to run the benchmark yourself.

## What you get

<div class="grid cards" markdown>

-   :material-lightning-bolt: **Fast by default**

    A Rust HTTP server, one isolate per CPU core and streamed bodies.
    `dox build` makes one native binary. See [Performance](digging-deeper/performance.md).

-   :material-database-outline: **ORM and query builder**

    Models, relations, migrations and transactions for Postgres, MySQL/MariaDB and SQLite,
    with native Rust drivers. See [Database](database/index.md).

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

    [WebSocket](digging-deeper/websocket.md) or [Socket.IO](packages/socketio.md), with Redis for many servers.

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
- Want to help? Read [Contribute](others/contribute.md).

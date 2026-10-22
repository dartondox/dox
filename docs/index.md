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
[Get started](the-basic/installation.md){ .md-button .md-button--primary }
[GitHub](https://github.com/dartondox/dox){ .md-button }
</p>

</div>

<div class="dox-hero__code" markdown>

```dart
Route.get('/blogs', BlogController.index);

enum Status { active, draft }

@Dto()
class BlogFilter {
  final Status status; // ?status=active, else 422
  const BlogFilter({required this.status});
  static const DtoSchema<BlogFilter> schema = $BlogFilterDto;
}

class BlogController {
  static Future<List<Blog>> index(BlogFilter query) async {
    // runs on Postgres, MySQL or SQLite
    return Blog().where('status', query.status.name).get();
  }
}
```

</div>

</div>

!!! warning "You are reading the 3.x docs (alpha)"
    `3.0.0-alpha.4` is a preview. Things can still change before the stable release.

    - New here? Start with [Installation](the-basic/installation.md).
    - Need the old docs? Pick **2.x** in the version menu at the top.

## Quick start

You need Dart 3.13 or newer.

```bash
dart pub global activate dox 3.0.0-alpha.4   # install the CLI
dox create new_blog                          # make a new project
cd new_blog && dox s                         # start the server
```

The server uses the port in `APP_PORT` in the `.env` file. Open `/ping` on that port to check it.
See [Installation](the-basic/installation.md) for the details.

## Why Dox

<div class="grid cards" markdown>

-   :material-lightning-bolt: **Fast by default**

    One isolate per CPU core and streamed bodies. `dox build` makes an AOT native binary.
    See [Performance](digging-deeper/performance.md).

-   :material-database-outline: **ORM and query builder**

    Models, relations, migrations and transactions for Postgres, MySQL/MariaDB and SQLite.
    See [Database](database/index.md).

-   :material-check-decagram-outline: **Typed validation**

    Typed DTO classes, checked by generated code. See [Validation](the-basic/validation.md).

-   :material-file-document-outline: **OpenAPI**

    Make OpenAPI 3.1 docs and a Scalar docs page with [`dox_openapi`](packages/openapi.md).

-   :material-folder-outline: **File storage**

    Local disk and S3 behind one API with [`dox_storage`](packages/storage.md).

-   :material-cached: **Cache**

    Memory, file and Redis cache with [`dox_cache`](packages/cache.md).

-   :material-access-point: **Real time**

    Events with [WebSocket](digging-deeper/websocket.md) or [Socket.IO](packages/socketio.md).

-   :material-shield-lock-outline: **Security**

    JWT [authentication](security/authentication.md), [CORS](security/cors.md), [encryption](security/encryption.md) and [hashing](security/hashing.md).

-   :material-console: **CLI**

    Create projects, controllers, models and migrations, and build for production.
    See [Dox CLI](digging-deeper/dox-cli.md).

</div>

---
title: Getting Started
description: Dox is a fast web backend framework for Dart. Routing, an ORM, migrations, typed validation, auth and a CLI, on a native HTTP server.
hide:
  - toc
---

<div class="dox-top" markdown>

<div class="dox-top__text" markdown>

![Doxie, the Dox mascot](assets/mascot.png){ .dox-top__mascot width="110" height="108" }

# Fast backends in Dart

<p class="dox-top__slogan">Everything your Dart backend needs.</p>

<p class="dox-top__lead">
Build APIs and full web apps in Dart, with batteries included.
Routing, an ORM, validation, auth and a CLI work from the first command.
One command adds the rest: queues, mail, GraphQL and more.
Your app uses every CPU core and ships as one small native binary.
</p>

<p class="dox-top__actions" markdown>
[Build your first API](tutorial/index.md){ .md-button .md-button--primary }
[GitHub](https://github.com/dartondox/dox){ .md-button }
[Blog](/blog/){ .md-button }
</p>

</div>

<div class="dox-top__side" markdown>

<div class="dox-bench" markdown>

<div class="dox-bench__grid">
  <span></span><span></span>
  <span class="dox-bench__head">req/s</span>
  <span class="dox-bench__head">p99</span>
  <span class="dox-bench__head dox-bench__head--ram">RAM</span>

  <div class="dox-bench__row dox-bench__row--win">
    <span class="dox-bench__name"><strong>Dox</strong><span>native server</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 100%"></span></span>
    <span class="dox-bench__num">652,400<span class="dox-bench__vs">fastest</span></span>
    <span class="dox-bench__p99">0.7 ms</span>
    <span class="dox-bench__ram">21 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Rust</strong><span>hyper</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 87.7%"></span></span>
    <span class="dox-bench__num">572,132<span class="dox-bench__vs">1.14× slower</span></span>
    <span class="dox-bench__p99">0.8 ms</span>
    <span class="dox-bench__ram">14 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Bun</strong><span>Bun.serve</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 77.4%"></span></span>
    <span class="dox-bench__num">504,672<span class="dox-bench__vs">1.29× slower</span></span>
    <span class="dox-bench__p99">1.0 ms</span>
    <span class="dox-bench__ram">40 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Relic 2</strong><span>relic_native</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 72.2%"></span></span>
    <span class="dox-bench__num">471,005<span class="dox-bench__vs">1.39× slower</span></span>
    <span class="dox-bench__p99">0.7 ms</span>
    <span class="dox-bench__ram">40 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Node</strong><span>node:http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 43.2%"></span></span>
    <span class="dox-bench__num">282,130<span class="dox-bench__vs">2.3× slower</span></span>
    <span class="dox-bench__p99">1.7 ms</span>
    <span class="dox-bench__ram">199 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>Go</strong><span>net/http</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 36.3%"></span></span>
    <span class="dox-bench__num">237,146<span class="dox-bench__vs">2.8× slower</span></span>
    <span class="dox-bench__p99">3.3 ms</span>
    <span class="dox-bench__ram">36 MB</span>
  </div>
  <div class="dox-bench__row">
    <span class="dox-bench__name"><strong>dart:io</strong><span>HttpServer</span></span>
    <span class="dox-bench__track"><span class="dox-bench__bar" style="--w: 19.2%"></span></span>
    <span class="dox-bench__num">124,996<span class="dox-bench__vs">5.2× slower</span></span>
    <span class="dox-bench__p99">4.8 ms</span>
    <span class="dox-bench__ram">56 MB</span>
  </div>
</div>

<p class="dox-bench__foot" markdown>[All results](digging-deeper/performance.md#benchmark)</p>

</div>

</div>

</div>

The speed comes from the native server. It runs on the isolate's own thread,
so a request never waits for another thread. See
[Performance](digging-deeper/performance.md) for every route and how it was run.

## What you get

<div class="dox-feat" markdown>

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

    Local disk and S3 behind one API, with signed URLs. See [`dox_storage`](digging-deeper/file-storage.md).

-   :material-cached: **Cache**

    Memory, file and Redis cache with tags and locks. See [`dox_cache`](digging-deeper/cache.md).

-   :material-access-point: **Real time**

    [Socket.IO](packages/socketio.md), with Redis for many servers.

-   :material-shield-lock-outline: **Security**

    JWT [authentication](security/authentication.md), [CORS](security/cors.md),
    [encryption](security/encryption.md) and [hashing](security/hashing.md).

-   :material-console: **CLI**

    Create projects, controllers, models and migrations. Run, build and migrate.
    See [CLI reference](reference/cli.md).

</div>

## One path for every request

<ol class="dox-flow" aria-label="The path of a request" markdown="block">
  <li markdown="span">**[Route](the-basic/routing.md)**<span>match the URL</span></li>
  <li markdown="span">**[Middleware](the-basic/middleware.md)**<span>go on or stop</span></li>
  <li markdown="span">**[DTO](the-basic/dto.md)**<span>check the input</span></li>
  <li markdown="span">**[Controller](the-basic/controller.md)**<span>your code</span></li>
  <li markdown="span">**[View](the-basic/views.md)**<span>render a page</span></li>
  <li markdown="span" class="dox-flow__end">**[Response](the-basic/response.md)**<span>send the answer</span></li>
</ol>

Each card is a page in "The basics". See [How Dox works](concepts/how-dox-works.md) for every step.

## What the code looks like

<div class="dox-sample" markdown>

<div class="dox-sample__code" markdown>

```dart
Route.post('/blogs', (BlogController c) => c.store);

@Inject() // 1
class BlogController {
  BlogController(this.blogs);
  final BlogService blogs;

  Future<Blog> store(CreateBlog input) { // 2
    return blogs.create(input);
  }
}

@Dto() // 3
class CreateBlog {
  @Length(min: 3, max: 100)
  final String title;

  @MinLength(10)
  final String body;
  ...
}
```

</div>

1.  Dox makes the controller and gives it the service it asks for. There is no reflection and no list of classes to keep.
2.  Ask for the DTO as a parameter. Dox reads the JSON body, checks it, and gives you a typed object. Bad input gets a `422` before your code runs.
3.  `@Dto()` marks an input class. The code generator writes the checks from the fields, their types and their rules.

</div>

## Run it in two minutes

You need [Dart](https://dart.dev/get-dart) 3.13 or newer, and nothing else.
The starter project uses SQLite, so there is no database to install.

<div class="dox-start" markdown>

<div markdown>

```bash title="Start the app"
dart pub global activate dox   # install the CLI
dox create my_app              # download the starter project
cd my_app
dart pub get
dox s                          # start the server
```

</div>

<div markdown>

```bash title="In a second terminal, call the first route"
curl localhost:3000/ping
```

```text
pong
```

</div>

</div>

That is a Dox app. Next, follow the [tutorial](tutorial/index.md). It adds a
model, a database table, validation, login and a Docker image, one short step
at a time.

??? note "The CLI is not found?"
    `dart pub global activate` puts `dox` in `$HOME/.pub-cache/bin`.
    Add that folder to your `PATH`. See [Installation](getting-started/installation.md).

## Pick your path

<div class="dox-paths" markdown>

-   New to Dox

    **[Tutorial: build a blog API](tutorial/index.md)**

    Then [Routing](the-basic/routing.md), [Request](the-basic/request.md), [Validation](the-basic/validation.md)

-   Coming from Laravel

    **[Coming from Laravel](concepts/coming-from-laravel.md)**

    Then [How Dox works](concepts/how-dox-works.md)

-   Looking for one answer

    **[Guides](guides/index.md)**

    Uploads, auth, Docker, pagination. Then [Reference](reference/index.md)

-   Going to production

    **[Deployment](digging-deeper/deployment.md)**

    Then [Docker](guides/docker.md), [Troubleshooting](reference/troubleshooting.md)

</div>

## Get help

<div class="dox-help" markdown>

- Found a bug or have a question? Open an [issue on GitHub](https://github.com/dartondox/dox/issues).
- Using an AI assistant? Install the package skills, or give it [llms-full.txt](https://dartondox.dev/llms-full.txt): all of these docs as one plain text file. See [AI agents](getting-started/ai-agents.md).
- Want to help? Read [Contribute](community/contribute.md).

</div>

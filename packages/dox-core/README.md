<div align="center">
<img src="https://raw.githubusercontent.com/dartondox/assets/main/dox-logo.png" width="70" />
</br></br>

<div style="display:inline-block">
<img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" height="20"/> <img src="https://github.com/dartondox/dox/actions/workflows/test.yaml/badge.svg?branch=main" height="20"/> <img src="https://img.shields.io/github/stars/dartondox/dox.svg" height="20"/> <img src="https://img.shields.io/github/forks/dartondox/dox.svg" height="20"/> <img src="https://img.shields.io/github/license/dartondox/dox.svg" height="20"/> <a href="https://www.bestpractices.dev/projects/16424"><img src="https://www.bestpractices.dev/projects/16424/badge" height="20"/></a> <a href="https://scorecard.dev/viewer/?uri=github.com/dartondox/dox"><img src="https://api.scorecard.dev/projects/github.com/dartondox/dox/badge" alt="OpenSSF Scorecard" height="20"/></a>
</div>

**Everything your Dart backend needs.**
</div>

Build your whole backend in Dart: a REST API, a full-stack web app,
or a real-time service.

Dox gives you what a real app needs in one framework: routes, database
models, input checks, login, background jobs, emails, file uploads and
WebSockets. You write your features. You do not glue ten packages together.

It is also fast. In our benchmark, a full Dox app serves more requests per
second than plain Bun, Node and Go servers, and uses little memory.
When you are ready to ship, `dox build` gives you one native binary to deploy.

[Documentation](https://dartondox.dev) · [Tutorial](https://dartondox.dev/tutorial/) · [Blog](https://dartondox.dev/blog/)

## Quick start

You need [Dart](https://dart.dev/get-dart) 3.13 or newer. The starter
project uses SQLite, so there is no database to install.

```bash
dart pub global activate dox   # install the CLI
dox create my_app              # download the starter project
cd my_app
dart pub get
dox s                          # start the server on port 3000
```

```bash
curl localhost:3000/ping       # pong
```

## Without the template

Dox also works in a plain Dart project. You do not need the CLI or the starter project.

Add the core package:

```bash
dart pub add dox_core
```

Put a secret key in `.env`. Dox uses it to encrypt cookies:

```bash
echo "APP_KEY=$(openssl rand -hex 16)" > .env
```

Write `bin/server.dart`:

```dart
import 'package:dox_core/dox_core.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  void register() {
    Route.get('/ping', (DoxRequest req) => 'pong');

    // {id} must be an int, so /api/users/abc gets a 404.
    Route.get('/users/{id}', (DoxRequest req, int id) {
      return <String, dynamic>{'id': id};
    });
  }
}

void main() async {
  Dox().initialize(AppConfig(
    appKey: Env.get('APP_KEY'),
    serverPort: 3000,
    routers: <Router>[ApiRouter()],
  ));
  await Dox().startServer();
}
```

Run it:

```bash
dart run bin/server.dart
curl localhost:3000/api/ping      # pong
curl localhost:3000/api/users/7   # {"id":7}
```

Add more packages when you need them, for example `dart pub add dox_orm`.

## A small example

A route, a typed input and a database query:

```dart
// lib/routes/api.dart
class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  void register() {
    Route.get('/ping', (DoxRequest req) => 'pong'); // GET /api/ping
    Route.get('/blogs', BlogController.index);       // GET /api/blogs
  }
}

enum Status { active, draft }

// build_runner makes the checks from the fields and their types.
@Dto()
class BlogFilter {
  final Status status; // ?status=active, anything else gets a 422
  const BlogFilter({required this.status});
  static const DtoSchema<BlogFilter> schema = $BlogFilterDto;
}

// lib/app/http/controllers/blog.controller.dart
class BlogController {
  // Dox reads the query, checks it and gives you a typed object.
  static Future<List<Blog>> index(BlogFilter query) async {
    return Blog().where('status', query.status.name).get();
  }
}
```

- Routers are found by `build_runner`. There is no list to keep up to date.
- A list or a map that you return is sent as JSON.
- The same ORM code runs on Postgres, MySQL and SQLite.

## Performance

A full Dox app against plain servers in other languages. It uses the rules of
[the-benchmarker/web-frameworks](https://github.com/the-benchmarker/web-frameworks):
`GET /`, 2 CPU cores, 256 connections, `wrk`. Higher req/s is better.

| Server | req/s | p99 | RAM |
| --- | ---: | ---: | ---: |
| **Dox** (full app) | **626,655** | 1.1 ms | 21 MB |
| Rust (hyper) | 585,658 | 0.7 ms | 13 MB |
| Bun (`Bun.serve`) | 501,529 | 1.0 ms | 40 MB |
| Node (`node:http`) | 286,847 | 1.7 ms | 200 MB |
| Go (`net/http`) | 242,043 | 3.3 ms | 36 MB |
| Dart (`dart:io` HttpServer) | 129,796 | 3.8 ms | 75 MB |

Read one row from Postgres (`GET /db`, same setup, Postgres 18):

| Server | req/s | p99 | RAM |
| --- | ---: | ---: | ---: |
| **Dox** (`dox_postgres_native`) | **297,000** | 2.6 ms | 93 MB |
| Bun (`Bun.sql`) | 198,296 | 2.1 ms | 64 MB |
| Rust (`tokio-postgres`) | 128,065 | 2.6 ms | 11 MB |
| Node (`pg`) | 75,447 | 4.1 ms | 232 MB |
| Go (`pgx`) | 55,903 | 6.3 ms | 31 MB |
| Dart (`package:postgres`) | 28,598 | 14.2 ms | 47 MB |

Numbers change from machine to machine. See
[Performance](https://dartondox.dev/digging-deeper/performance/#benchmark)
for every route, more cores, and how it was run.

## Features

**HTTP**

- Native HTTP server, one isolate per CPU core. Request bodies and uploads are streamed.
- Routing with groups, prefixes, middleware and route model binding.
- Typed input with `@Dto()` classes. Bad input gets a `422` before your code runs.
- CORS, CSRF, rate limiting, security headers, sessions and signed URLs.
- Server-side views (`dox_view`) or Inertia (`dox_inertia`) for full-stack apps.

**Data**

- ORM and query builder (`dox_orm`): models, relations and transactions for PostgreSQL, MySQL, MariaDB and SQLite. Postgres and MySQL use native drivers.
- Migrations (`dox_migration`).
- Cache (`dox_cache`): memory, file and Redis, with locks and tags. `dox_cache_database` keeps the cache in a database table.
- Storage (`dox_storage`): one API for local disk, AWS S3 and S3-compatible services.

**Background work**

- Queues (`dox_queue`), with Redis or database drivers.
- Scheduler (`dox_scheduler`) for jobs that run on a timer.
- Mail (`dox_mailer`).

**Auth and APIs**

- Authentication (`dox_auth`) with JWT and revocable access tokens. Hashing and encryption are built in.
- OpenAPI 3.1 docs (`dox_openapi`), made from your routes and DTOs, with a docs page.
- Schema validation (`dox_validation`): Zod-like schemas with typed results.

**Real time and AI**

- Socket.IO v4 server (`dox_socketio`) that works with the official clients, with a Redis adapter for many servers.
- MCP server (`dox_mcp`): tools for AI clients over the Model Context Protocol.

**CLI**

- `dox create`, `dox s`, `dox build`, `dox migrate`, `dox route:list`, and commands to make controllers, models and migrations.

## Repos

This repo holds `dox_core`, `dox_annotation`, `dox_builder` and `dox_cache`.
Some packages live in their own repos:

| Package | Repo |
| --- | --- |
| `dox` (the CLI) | [dartondox/dox-cli](https://github.com/dartondox/dox-cli) |
| `dox_orm`, `dox_migration`, `dox_cache_database` | [dartondox/dox-orm](https://github.com/dartondox/dox-orm) |
| `dox_auth` | [dartondox/dox-auth](https://github.com/dartondox/dox-auth) |
| `dox_openapi` | [dartondox/dox-openapi](https://github.com/dartondox/dox-openapi) |
| `dox_validation` | [dartondox/dox-validation](https://github.com/dartondox/dox-validation) |
| `dox_socketio` | [dartondox/dox-socketio](https://github.com/dartondox/dox-socketio) |
| `dox_storage` | [dartondox/dox-storage](https://github.com/dartondox/dox-storage) |
| `dox_queue` | [dartondox/dox-queue](https://github.com/dartondox/dox-queue) |
| `dox_scheduler` | [dartondox/dox-scheduler](https://github.com/dartondox/dox-scheduler) |
| `dox_mcp` | [dartondox/dox-mcp](https://github.com/dartondox/dox-mcp) |
| `dox_inertia` | [dartondox/dox-inertia](https://github.com/dartondox/dox-inertia) |
| `dox_view` | [dartondox/dox-view](https://github.com/dartondox/dox-view) |
| `dox_mailer` | [dartondox/dox-mailer](https://github.com/dartondox/dox-mailer) |
| `dox_http_native` | [dartondox/dox-http-native](https://github.com/dartondox/dox-http-native) |
| `dox_postgres_native` | [dartondox/dox-postgres-native](https://github.com/dartondox/dox-postgres-native) |
| `dox_mysql_native` | [dartondox/dox-mysql-native](https://github.com/dartondox/dox-mysql-native) |

## Documentation

For detailed information about the framework and its functionalities, refer to the [Dox Documentation](https://dartondox.dev).

## Security Vulnerabilities

Dox take the security of our framework seriously. If you identify any security vulnerabilities in our application, please notify us immediately by sending an email to support@dartondox.dev. We appreciate your responsible disclosure and will respond promptly to address and resolve any identified security issues. Your cooperation helps us maintain the integrity and safety of our software for all users.

## Contributing

We welcome contributions from the community! If you'd like to contribute to the Dox framework, please fork the repo and PR to us. Please visit [contribution guide](https://dartondox.dev/community/contribute/) for more information.

## Credits

Dox is inspired by [Laravel](https://laravel.com).

## License

This project is licensed under the [MIT License](https://github.com/dartondox/dox/blob/main/LICENSE).

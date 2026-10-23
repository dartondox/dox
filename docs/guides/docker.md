# Docker

Build a small production image with `dox build`, and run it with Postgres in Docker Compose, with a health check.

## What you need

- A Dox app with a database.
- Docker with Compose.

## 1. Add a health route

The health check asks this route. It fails when the database does not answer.

```dart title="lib/app/http/controllers/health.controller.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';

class HealthController {
  /// GET /health. 200 when the app and the database answer.
  /// Any database error becomes a 500, so the health check fails.
  Future<Map<String, String>> check(DoxRequest req) async {
    await QueryBuilder.query('select 1');
    return <String, String>{'status': 'ok'};
  }
}

HealthController healthController = HealthController();
```

```dart title="lib/routes/web.dart"
Route.get('/health', healthController.check);
```

## 2. Add the health check binary

The final image is `FROM scratch`. It has no shell and no `curl`. So the health check is a second small Dart binary.

```dart title="bin/health.dart"
import 'dart:io';

/// Docker health check. The final image has no shell and no curl,
/// so this small binary asks the app itself. Exit 0 = healthy.
Future<void> main() async {
  String port = Platform.environment['APP_PORT'] ?? '3000';
  HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);
  try {
    HttpClientRequest request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/health'),
    );
    HttpClientResponse response = await request.close();
    exit(response.statusCode == 200 ? 0 : 1);
  } catch (_) {
    exit(1);
  }
}
```

## 3. Write the Dockerfile

Two stages. The first one has the Dart SDK and the `dox` CLI, and builds the AOT bundle.
The second one has only the Dart runtime files and the bundle. No SDK, no source, no shell.

```dockerfile title="Dockerfile"
# Stage 1: build the AOT bundle with the Dart SDK and the dox CLI.
FROM dart:stable AS build

WORKDIR /app

# Resolve dependencies first, so Docker caches this layer.
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline

# `dox build` runs build_runner, then `dart build cli`.
# The bundle is in build/bundle: bin/server, lib/, db/, .env.example
RUN dart pub global activate dox ^3.0.0-alpha \
  && /root/.pub-cache/bin/dox build

# The health check binary. Plain dart:io, so `dart compile exe` is fine.
RUN dart compile exe bin/health.dart -o build/bundle/bin/health

# Lay out the final file tree. /tmp must be writable: uploads bigger
# than 1 MB are streamed to a temp file.
RUN mkdir -p /out/app/storage /out/app/public /out/tmp \
  && chmod 1777 /out/tmp \
  && cp -r build/bundle/. /out/app/ \
  && cp -r public/. /out/app/public/ \
  # the native HTTP server (Rust) needs libgcc_s, which /runtime/ does not have
  && LIBGCC=$(find / -name libgcc_s.so.1 -path '*lib*' | head -n 1) \
  && mkdir -p /out$(dirname $LIBGCC) && cp $LIBGCC /out$LIBGCC

# Stage 2: the Dart AOT runtime and the bundle only. No SDK, no source.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/ /
WORKDIR /app

# Config comes from env variables. The image has no .env file.
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/app/bin/health"]
CMD ["/app/bin/server"]
```

Delete the `public` lines when your app has no `public` folder.

Check the start log in the container. It must end with `(native)`:

```text
Server started at http://[::]:3000 with 8 isolate (native)
```

Without the `libgcc_s` lines, the native HTTP server does not load in a
`scratch` image. Dox then prints `dox_http_native did not load, using the
dart:io server` and runs on the slower `dart:io` server.

!!! warning "`dox build`, not `dart compile exe`"
    `dox_orm` bundles SQLite with a build hook. `dart compile exe` does not run build hooks and stops with an error.
    `dox build` runs `dart build cli`, which does. It puts the native libraries in `build/bundle/lib`, next to `bin/server`.

Keep the build context small:

```text title=".dockerignore"
.dart_tool/
.git/
.github/
.idea/
build/
storage/
.env
.env.*
!.env.example
Dockerfile
docker-compose.yml
pubspec_overrides.yaml
```

## 4. Write the compose file

The app reads its config from env variables. `env_file: .env` gives it your `.env`. The lines under `environment` win over the file, so the app always talks to the `postgres` service.

```yaml title="docker-compose.yml"
services:
  app:
    build: .
    # secrets and config come from .env, never from the image
    env_file: .env
    environment:
      APP_ENV: production
      APP_PORT: 3000
      DB_CONNECTION: postgres
      DB_HOST: postgres
      DB_PORT: 5432
    ports:
      - "3000:3000"
    volumes:
      # uploads survive a new image
      - uploads:/app/storage
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped

  postgres:
    image: postgres:18
    environment:
      POSTGRES_USER: ${DB_USERNAME:-postgres}
      POSTGRES_PASSWORD: ${DB_PASSWORD:?set DB_PASSWORD in .env}
      POSTGRES_DB: ${DB_NAME:-dox}
    volumes:
      - postgres:/var/lib/postgresql
    healthcheck:
      test: ["CMD", "pg_isready", "-q", "-U", "${DB_USERNAME:-postgres}"]
      interval: 5s
      retries: 10
    restart: unless-stopped

volumes:
  postgres:
  uploads:
```

- `depends_on` with `service_healthy`: the app starts after Postgres answers. The app runs the migrations at start, so the database must be up.
- `${DB_PASSWORD:?...}`: compose stops with a clear message when `.env` has no password.
- `restart: unless-stopped`: when the main isolate dies, the process exits and Docker starts it again.

## 5. Write the `.env`

```ini title=".env"
APP_NAME=my_app
APP_ENV=production
APP_KEY=<output of dox key:generate>
APP_PORT=3000

DB_CONNECTION=postgres
DB_NAME=my_app
DB_USERNAME=postgres
DB_PASSWORD=<a real password>
```

`.env` is in `.dockerignore` and `.gitignore`. It never goes into the image or into git.

## 6. Build and run

```bash
docker compose up -d --build
docker compose ps
```

## Check it

```bash
docker compose ps
```

```text
NAME             STATUS
my_app-app-1       Up 30 seconds (healthy)
my_app-postgres-1  Up 35 seconds (healthy)
```

```bash
curl http://localhost:3000/health
```

```json
{"status":"ok"}
```

Stop Postgres with `docker compose stop postgres`. After about 45 seconds, `docker compose ps` shows the app as `unhealthy`.

## HTTPS

Do not add TLS to the app. Put Caddy or nginx in front, and set `trustedProxies` in `AppConfig`.
See [Deployment: HTTPS](../digging-deeper/deployment.md#https-put-a-proxy-in-front).

## See also

- [Deployment](../digging-deeper/deployment.md) for `dox build`, the bundle layout and systemd
- [Environments](environments.md) for dev, staging and production config
- [Migration: run on server start](../database/migration.md#run-on-server-start)

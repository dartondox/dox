---
icon: lucide/container
---

# Docker

Build a small production image with `dox build`, and run it with Postgres in Docker Compose, with a health check.

The image holds only the compiled app, so it is small and starts fast.

## What you need

- A Dox app with a database.
- Docker with Compose.

## 1. Add a health route

Docker asks this route if the app works. It answers 503 when the database does not answer. Put it in `register()` of `WebRouter`:

```dart title="lib/routes/web.dart"
Route.health(
  '/health',
  checks: <String, HealthCheckFunction>{
    'database': () => QueryBuilder.query('select 1'),
  },
);
```

## 2. Add the health check binary

The final image has no shell and no `curl`, so the health check is a small Dart binary:

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

The first stage builds the AOT bundle. The second stage holds only the Dart runtime and the bundle, about 17 MB for the blog API:

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
# (and bin/queue, bin/schedule when the app has them)
RUN dart pub global activate dox \
  && /root/.pub-cache/bin/dox build

# The health check binary. Plain dart:io, so `dart compile exe` is fine.
RUN dart compile exe bin/health.dart -o build/bundle/bin/health

# Lay out the final file tree. /tmp must be writable: uploads bigger
# than 1 MB are streamed to a temp file.
RUN mkdir -p /out/app/storage /out/app/public /out/tmp \
  && chmod 1777 /out/tmp \
  && cp -r build/bundle/. /out/app/ \
  && cp -r public/. /out/app/public/

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

Delete the `public` lines if your app has no `public` folder.

The image has no copy of `libgcc_s.so.1`. The native libraries do not need it from `dox_http_native` 3.2.4, `dox_postgres_native` 3.2.2 and `dox_mysql_native` 3.2.2. With an older version, Dox stops at start with `dox_http_native did not load`. Run `dart pub upgrade` to get the new versions.

When the container starts, the start log must end with `(native)`:

```text
[server] Server started at http://[::]:3000 with 8 isolate (native)
```

!!! warning "`dox build`, not `dart compile exe`"
    `dox_orm` bundles SQLite with a build hook. `dart compile exe` does not run build hooks and stops with an error. Build the server with `dox build`.

Keep the build context small with a `.dockerignore`:

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

Docker Compose runs the app and Postgres together. The lines under `environment` win over `.env`:

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

`depends_on` starts the app after Postgres answers, because the app runs the migrations at start.

## 5. Write the `.env`

Put the secrets in `.env`. It never goes into the image or into git:

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

A new app skips the Postgres driver in `pubspec.yaml`. Remove the `dox_postgres_native` skip lines. See [Skip unused drivers](../database/index.md#skip-unused-drivers).

## 6. Build and run

Build the image and start both services:

```bash
docker compose up -d --build
```

## Check it

Both services are healthy:

```bash
docker compose ps
```

```text
NAME             STATUS
my_app-app-1       Up 30 seconds (healthy)
my_app-postgres-1  Up 35 seconds (healthy)
```

Ask the health route:

```bash
curl http://localhost:3000/health
```

```json
{"status":"ok","checks":{"database":"ok"}}
```

Now stop Postgres with `docker compose stop postgres`. After about 45 seconds, `docker compose ps` shows the app as unhealthy.

## HTTPS

Put Caddy or nginx in front of the app, and set `trustedProxies` in `AppConfig`. See [Deployment: HTTPS](../digging-deeper/deployment.md#https-put-a-proxy-in-front).

## Next steps

- [Deployment](../digging-deeper/deployment.md): `dox build`, the bundle and systemd.
- [Health check](../digging-deeper/health-check.md): more checks.
- [Environments](environments.md): dev, staging and production config.
- [Migration: run on server start](../database/migration.md#run-on-server-start): the migrations at start.

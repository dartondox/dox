---
icon: lucide/package
---

# Step 7: Build and deploy

In this step you compile the app to one native binary, run it, and run it in Docker.

!!! warning "Use a native binary in production"
    `dox s` and `dart run` use the JIT compiler. It uses approximately 25 times more memory and starts slower.

## 1. Build the binary

Build the app:

```bash
dox build
```

```text
Built with build_runner/aot in 1s; wrote 0 outputs.
Running build hooks...Running link hooks...
Generated: /.../blog/build/bundle/bin/server
[Dox] Built build/bundle. Run it with: cd build/bundle && ./bin/server
```

It runs the code generator, then `dart build cli`. The `build/bundle` folder has all that the app needs:

| Path | What it is |
| --- | --- |
| `bin/server` | the binary, approximately 10 MB. It needs no Dart SDK. |
| `bin/queue` | the [queue worker](../digging-deeper/queue.md). Run it as its own process. |
| `bin/schedule` | the [scheduler](../digging-deeper/scheduler.md). Run it as its own process. |
| `lib/` | native libraries from build hooks, like `libsqlite3`. Keep it next to `bin/`. |
| `db/` | your migrations. Your local SQLite file is not copied. |
| `.env.example` | a copy of the example env file. |

## 2. Run the binary

The binary reads `.env` from the folder where you start it, so copy your file there:

```bash
cd build/bundle
cp ../../.env .env
./bin/server
```

```text
Migrating: 2023_07_16_131937700_create_users_table
Migrated: 2023_07_16_131937700_create_users_table
Migrating: 2026_10_25_000000000_create_queue_tables
Migrated: 2026_10_25_000000000_create_queue_tables
Migrating: 2026_10_22_205345_create_posts_table
Migrated: 2026_10_22_205345_create_posts_table
... "message":"Server started at http://[::]:3000 with 8 isolate (native)" ...
```

The migrations run again, because the bundle has a new database file. The binary has the migration list in it.

On a server you can set real environment variables in place of `.env`. They win over `.env`.

## Check it

Call the binary from a second terminal:

```bash
curl http://localhost:3000/api/ping
curl http://localhost:3000/api/posts
```

```text
pong
[]
```

The list is empty, because the database file is new. Stop the server with Ctrl+C.

## 3. Docker

The project has a `Dockerfile`. It builds the same bundle and copies it into an empty scratch image:

```dockerfile title="Dockerfile"
FROM dart:stable AS build

# Resolve dependencies first, so this layer is cached.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline

# The dox CLI. `dox build` runs build_runner, then AOT-compiles
# bin/server.dart, bin/queue.dart and bin/schedule.dart with
# `dart build cli`. It puts all of them in build/bundle/bin, the native
# libraries in build/bundle/lib and the migrations in build/bundle/db.
# The queue worker and the scheduler run as their own processes:
# `/app/bin/queue work` and `/app/bin/schedule work`.
RUN dart pub global activate dox
RUN /root/.pub-cache/bin/dox build

# Lay out the final file tree:
# /app/bin/server, /app/bin/queue, /app/bin/schedule, /app/lib (native
# libraries), /app/db/migration, /app/storage and a writable /tmp
# (uploads bigger than 1 MB are streamed to a temp file).
RUN mkdir -p /out/app/storage /out/tmp \
  && chmod 1777 /out/tmp \
  && cp -r build/bundle/. /out/app/

# Minimal serving image: the AOT runtime files from the dart image
# (`/runtime/`) plus our bundle. No Dart SDK, no source code.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/ /
WORKDIR /app

# Config comes from env variables. The image has no .env file,
# so secrets stay out of it.
EXPOSE 3000
CMD ["/app/bin/server"]
```

Build and run the image. The image has no `.env` file, so give the config as environment variables. The app key must have exactly 32 characters, or the app does not start:

```bash
docker build -t blog .
docker run -p 3000:3000 \
  -e APP_KEY=$(openssl rand -hex 16) \
  -e DB_CONNECTION=sqlite \
  -e DB_NAME=storage/blog.sqlite \
  blog
```

!!! warning "SQLite in Docker"
    The database file is in the container, so you lose it when you remove the container. Mount a volume for it: `-v blog-data:/app/storage`. For a busy app, use Postgres or MySQL. See [Database](../database/index.md).

## Next steps

- [Deployment](../digging-deeper/deployment.md): HTTPS with a proxy, systemd, many machines.
- [Model](../database/model/index.md): relationships and events.
- [Serializer](../the-basic/serializer.md): change the JSON shape of a response.
- [Authentication](../security/authentication.md): all options of the auth package.
- [OpenAPI](../packages/openapi.md): API docs from your routes and DTOs.

# Step 7: Build and deploy

This step compiles the app to one native binary, runs it, and shows the `Dockerfile` of the project.

!!! warning "Never run production with `dox s` or `dart run`"
    They use the JIT compiler. It needs about 25 times more memory and starts slower.
    Build a native (AOT) binary for production.

## 1. Build the binary

```bash
dox build
```

```text
Built with build_runner/aot in 1s; wrote 0 outputs.
Running build hooks...Running link hooks...
Generated: /.../blog/build/bundle/bin/server
[Dox] Built build/bundle. Run it with: cd build/bundle && ./bin/server
```

`dox build` runs the code generator, then `dart build cli --target bin/server.dart --output build`.
The result is in `build/bundle`:

| Path | What it is |
| --- | --- |
| `bin/server` | the binary, about 10 MB. It needs no Dart SDK. |
| `lib/` | native libraries from build hooks, like `libsqlite3`. Keep it next to `bin/`. |
| `db/` | your migrations |

## 2. Run the binary

The binary reads `.env` from the folder you start it in. Copy yours there,
and make the `db` folder for the SQLite file:

```bash
cd build/bundle
cp ../../.env .env
mkdir -p db
./bin/server
```

```text
Migrating: 2023_07_16_131937700_create_users_table
Migrated: 2023_07_16_131937700_create_users_table
Migrating: 2026_10_22_205345_create_posts_table
Migrated: 2026_10_22_205345_create_posts_table
Server started at http://127.0.0.1:3000 with 8 isolate (native)
```

The migrations run again, because `DB_NAME=db/dox.sqlite` is a new file in `build/bundle`.
The registry in `db/migration/migrations.dart` is compiled into the binary, so this works without the source code.

A real environment variable wins over `.env`. So on a server you can skip the `.env` file and set the values in the environment.

## Check it

In a second terminal:

```bash
curl http://localhost:3000/api/ping
curl http://localhost:3000/api/posts
```

```text
pong
[]
```

The list is empty, because this is a new database file. Stop the server with `Ctrl+C`.

## 3. Docker

The project has a `Dockerfile`. It builds the same bundle in a `dart:stable` image and copies it to an empty (`scratch`) image. The final image holds only the binary, the native libraries and the migrations:

```dockerfile title="Dockerfile"
FROM dart:stable AS build

# Resolve dependencies first, so this layer is cached.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart run build_runner build --delete-conflicting-outputs

# `dart build cli` is AOT like `dart compile exe`, and it also runs
# build hooks. Native libraries go to build/bundle/lib.
RUN dart build cli --target bin/server.dart --output build

# Lay out the final file tree:
# /app/bin/server, /app/lib (native libraries), /app/db/migration,
# /app/storage and a writable /tmp (uploads bigger than 1 MB are
# streamed to a temp file).
RUN mkdir -p /out/app/storage /out/tmp \
  && chmod 1777 /out/tmp \
  && cp -r build/bundle/. /out/app/ \
  && cp -r db /out/app/db \
  # the native HTTP server (Rust) needs libgcc_s, which /runtime/ does not have
  && LIBGCC=$(find / -name libgcc_s.so.1 -path '*lib*' | head -n 1) \
  && mkdir -p /out$(dirname $LIBGCC) && cp $LIBGCC /out$LIBGCC

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

Build and run it. The image has no `.env` file, so pass the config as environment variables:

```bash
docker build -t blog .
docker run -p 3000:3000 \
  -e APP_KEY=change-me \
  -e DB_CONNECTION=sqlite \
  -e DB_NAME=storage/blog.sqlite \
  blog
```

!!! note "SQLite in Docker"
    The database file lives inside the container. It is lost when the container is removed.
    Mount a volume for it: `-v blog-data:/app/storage`.
    For a busy app, use Postgres or MySQL. See [Database](../database/index.md).

## Where to go next

- [Deployment](../digging-deeper/deployment.md): HTTPS with a proxy, systemd, many machines.
- [Model](../database/model/index.md): relationships, events, serializers.
- [Authentication](../security/authentication.md): all options of `dox_auth`.
- [OpenAPI](../packages/openapi.md): API docs from your routes and DTOs.

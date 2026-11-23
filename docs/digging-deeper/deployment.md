---
icon: lucide/cloud-upload
---

# Deployment

This page shows how to build a Dox app for production and run it safely.

You build the app into a native binary, copy it to a server or a Docker image, and put a proxy in front of it for HTTPS.

!!! danger "Never run production with `dart run`"
    `dart run` and `dox serve` use the JIT compiler, which is for
    development. It uses about 25x more memory at start (around 390 MB
    instead of 16 MB) and starts slower. Always build an AOT binary for
    production.

## Build

`dox build` builds your app for production into `build/bundle/`:

```bash
dox build
```

| File                        | What it is                                       |
| --------------------------- | ------------------------------------------------ |
| `build/bundle/bin/server`   | the native binary. It needs no Dart SDK          |
| `build/bundle/bin/queue`    | the queue worker, when `bin/queue.dart` exists   |
| `build/bundle/bin/schedule` | the scheduler, when `bin/schedule.dart` exists   |
| `build/bundle/lib/`         | native libraries from build hooks (like SQLite)  |
| `build/bundle/db/`          | your `db/` folder, with no SQLite database files |
| `build/bundle/.env.example` | copy it to `build/bundle/.env`, or use env variables |

Keep `bin/` and `lib/` together, because the binary loads the native libraries from `../lib`. Do not use `dart compile exe`: it does not run build hooks, so the app has no native libraries.

### Starting the server

Start the binary from the bundle folder. It reads `.env` and `db/` from the folder you start it in:

```bash
cd build/bundle
./bin/server
```

A real environment variable wins over the `.env` file. A new Dox app runs the migrations in `bin/server.dart`, before the server starts.

## Docker

A new Dox app has this multi-stage `Dockerfile`. The final image is `FROM scratch`: only the Dart AOT runtime, the bundle, `libgcc_s` and an empty `/tmp`.

```dockerfile
FROM dart:stable AS build

# Resolve dependencies first, so this layer is cached.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline

# `dox build` runs build_runner, then builds bin/server.dart,
# bin/queue.dart and bin/schedule.dart into build/bundle.
RUN dart pub global activate dox
RUN /root/.pub-cache/bin/dox build

# The final file tree: /app/bin, /app/lib, /app/db, /app/storage and
# a writable /tmp (uploads bigger than 1 MB go to a temp file).
RUN mkdir -p /out/app/storage /out/tmp \
  && chmod 1777 /out/tmp \
  && cp -r build/bundle/. /out/app/ \
  # the native HTTP server (Rust) needs libgcc_s
  && LIBGCC=$(find / -name libgcc_s.so.1 -path '*lib*' | head -n 1) \
  && mkdir -p /out$(dirname $LIBGCC) && cp $LIBGCC /out$LIBGCC

# The AOT runtime files of the dart image plus the bundle.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/ /
WORKDIR /app

# Config comes from env variables. The image has no .env file.
EXPOSE 3000
CMD ["/app/bin/server"]
```

The image has no `.env` file, so secrets stay out of it. Pass the config as environment variables:

```bash
docker build -t my-app .
docker run -p 3000:3000 --env-file .env -e DB_HOST=... my-app
```

### Docker compose

A new app also has a `docker-compose.yml`. It runs the app, a queue worker and Postgres:

```bash
docker compose up -d --build
```

- The compose services set `DB_CONNECTION=postgres` and `DB_NAME=dox`. To use this Postgres with `dox s`, set the same two values in `.env`.
- A new app skips the Postgres driver in `pubspec.yaml`. Remove the `dox_postgres_native` skip lines first. See [Skip unused drivers](../database/index.md#skip-unused-drivers).

See [Docker](../guides/docker.md) for a health check in the image.

## Running the queue worker and scheduler

One build has three binaries. Run each one as its own process:

| Process | Command |
| --- | --- |
| web server | `/app/bin/server` (the default `CMD`) |
| queue worker | `/app/bin/queue work` |
| scheduler | `/app/bin/schedule work` |

The image has no shell, so start the other binaries with `--entrypoint`:

```bash
docker run -d -p 3000:3000 --env-file .env my-app
docker run -d --env-file .env --entrypoint /app/bin/queue my-app work
docker run -d --env-file .env --entrypoint /app/bin/schedule my-app work
```

In compose, use `command: ["/app/bin/queue", "work"]`. With no Docker, run `./bin/queue work` and `./bin/schedule work` in `build/bundle`. Only the server runs the migrations, so start the server first.

A small app can run the jobs and the schedule inside the server, with `QueueConfig(inProcess: true)` and `ScheduleConfig(inProcess: true)`. See [Running jobs in the web server](queue.md#running-jobs-in-the-web-server).

## HTTPS: put a proxy in front

Dox serves plain HTTP only. Run it on a private port, and put [Caddy](https://caddyserver.com) or nginx in front of it for TLS and gzip. When the proxy is on the same machine, set `APP_HOST=127.0.0.1`:

```mermaid
flowchart LR
    C["Client"] -->|HTTPS| X["Caddy or nginx"]
    X -->|HTTP| D["Dox"]
    D --> DB[("Database")]
```

### Trusting the proxy

Tell Dox to trust the proxy, so `req.ip()` and `req.scheme()` show the real client:

```dart
AppConfig(
  // the IP of the proxy, or a range like '10.0.0.0/8'
  trustedProxies: <String>['127.0.0.1', '::1'],
);
```

`req.ip()` then reads `X-Forwarded-For`, and `req.scheme()` reads `X-Forwarded-Proto`. The list is empty by default, so Dox ignores these headers. `['*']` trusts any direct client, so use it only when the app port can not be reached from outside.

### Caddy

Caddy gets a certificate for you and sets the forwarded headers. WebSockets work with no extra config:

```
example.com {
  encode gzip
  reverse_proxy 127.0.0.1:3000
}
```

### Nginx

```nginx
upstream dox {
  server 127.0.0.1:3000;
  keepalive 64;
}

map $http_upgrade $connection_upgrade {
  default upgrade;
  ''      '';
}

server {
  listen 443 ssl http2;
  server_name example.com;

  ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

  # match maxMultipartSize in AppConfig
  client_max_body_size 100m;

  gzip on;
  gzip_types application/json text/plain text/css application/javascript;

  location / {
    proxy_pass http://dox;
    proxy_http_version 1.1;

    # websocket upgrade
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # stream uploads to Dox, do not buffer them in nginx first
    proxy_request_buffering off;
  }
}

server {
  listen 80;
  server_name example.com;
  return 301 https://$host$request_uri;
}
```

### HTTP/2 and gRPC

gRPC needs HTTP/2 between the proxy and Dox. Set `http2: true` in `AppConfig` (see [HTTP/2](http2.md)). Dox speaks h2c, so the proxy keeps the TLS. HTTP/1.1 and HTTP/2 use the same port.

With Caddy, `h2c://` sends HTTP/2 with no TLS to the app:

```
example.com {
  reverse_proxy h2c://127.0.0.1:3000
}
```

With nginx, use `grpc_pass` for the gRPC paths and `proxy_pass` for the other routes:

```nginx
server {
  listen 443 ssl;
  http2 on;
  server_name example.com;

  ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

  # Normal routes: HTTP/1.1 to the app
  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
  }

  # gRPC service paths only
  location /greeter.Greeter/ {
    grpc_pass grpc://127.0.0.1:3000;
  }
}
```

The nginx `grpc_read_timeout` and `grpc_send_timeout` are 60 seconds by default, and a quiet stream stops after that time. Raise them for long streams.

### Pass the real `Host` header

The proxy must pass the real `Host` header, like `proxy_set_header Host $host;` above. If it sends its own host, the WebSocket origin check gives 403, and `back()` goes to the fallback.

## Behind a load balancer

Dox closes an idle connection after 30 seconds. Set `idleTimeout` longer than the idle timeout of the balancer, or clients can get 502. AWS ALB keeps idle connections for 60 seconds, so use 65 seconds:

```dart
AppConfig(
  // ...
  idleTimeout: Duration(seconds: 65),
)
```

## Keep it running

When the main isolate dies, the process exits with a non-zero code. See [Isolate](isolate.md#when-an-isolate-crashes). Let a supervisor restart it, like `restart: unless-stopped` in Docker compose or `Restart=always` in systemd:

```ini
# /etc/systemd/system/dox.service
[Service]
WorkingDirectory=/srv/app/build/bundle
ExecStart=/srv/app/build/bundle/bin/server
EnvironmentFile=/srv/app/build/bundle/.env
Restart=always

[Install]
WantedBy=multi-user.target
```

## Graceful shutdown

On SIGTERM (docker stop, Kubernetes, Cloud Run, systemd) and SIGINT (Ctrl+C), Dox lets open requests finish. In every isolate it:

1. stops taking new connections,
2. lets open requests finish, for `shutdownTimeout` at most (8 seconds by default),
3. runs `shutdown()` of every provider (see [Providers](providers.md#clean-up-on-shutdown)),
4. closes the cache stores of `Cache()`,
5. exits with code 0.

A second signal stops the process at once. Set the timeout in `lib/config/app.dart`:

```dart
AppConfig(
  shutdownTimeout: Duration(seconds: 20),
  // ...
)
```

Keep it shorter than the time your platform waits before it kills the process:

| Platform | Waits | Change it with |
| --- | --- | --- |
| `docker stop` | 10 seconds | `docker stop -t 30`, or `stop_grace_period` in compose |
| Kubernetes | 30 seconds | `terminationGracePeriodSeconds` |
| Cloud Run | 10 seconds | can not be changed |
| Fly.io | 5 seconds | `kill_timeout` in `fly.toml` |
| systemd | 90 seconds | `TimeoutStopSec` |

### Stopping in code

`Dox().stop()` does steps 1 to 4, and the process keeps running:

```dart
await Dox().stop();
```

## Many processes or machines

One Dox process uses every core. Run more processes only for more machines, or to restart one process with no downtime. List them in the proxy:

```nginx
upstream dox {
  server 10.0.0.11:3000;
  server 10.0.0.12:3000;
  keepalive 64;
}
```

Socket.IO rooms then need a shared adapter, like Redis.

## Next steps

- [Docker](../guides/docker.md): a full Docker setup.
- [Deploy to a Linux server](../guides/deploy-vps.md): your own server with systemd and Caddy.
- [Deploy to Fly.io](../guides/deploy-fly.md): Fly.io.
- [Deploy to Google Cloud Run](../guides/deploy-cloud-run.md): Google Cloud Run.
- [Production checklist](../reference/production-checklist.md): what to check before you deploy.

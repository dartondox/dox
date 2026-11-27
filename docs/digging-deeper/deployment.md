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

A new Dox app has this multi-stage `Dockerfile`. The final image is `FROM scratch`: only the Dart AOT runtime, the bundle and an empty `/tmp`.

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
  && cp -r build/bundle/. /out/app/

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

## HTTPS without a proxy

Dox can serve HTTPS itself, so a small server needs no proxy for TLS. The TLS work is in Rust (rustls), in the [native server](native-server.md). TLS is off by default.

Use a proxy when you also want gzip, automatic certificates or more than one app on a server. See [HTTPS: put a proxy in front](#https-put-a-proxy-in-front).

### Turn on TLS

Set `tls` in the app config. Give the certificate file and the key file:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  serverPort: 443,
  tls: TlsOptions(
    certificatePath: '/etc/letsencrypt/live/example.com/fullchain.pem',
    keyPath: '/etc/letsencrypt/live/example.com/privkey.pem',
  ),
  // ...
);
```

| Option | What it is |
| --- | --- |
| `certificatePath` | A PEM file. The certificate is first, then the intermediate certificates. An example is `fullchain.pem` of certbot. |
| `keyPath` | A PEM file with the private key of the certificate (PKCS #8, PKCS #1 or SEC1). An example is `privkey.pem` of certbot. |

- Dox reads the two files when the server starts. A bad file, or a key of a different certificate, throws a `TlsException`, and the server does not start.
- The user of the app must have permission to read the two files.
- The server uses TLS 1.2 and TLS 1.3. There are no cipher options.
- The TLS handshake must end in `idleTimeout`.
- Your routes stay the same. WebSocket (`wss://`) and streamed responses work on the TLS port.
- `req.scheme()` is `https` and `req.isSecure()` is true. Thus the session cookie and other cookies get `Secure`, and `SecurityHeaders` sends HSTS.
- Set `APP_URL` to the `https://` address, because signed URLs and absolute URLs use it.
- gzip is off by default. With no proxy, set `compress: true` if you want gzip.

On Linux, a port below 1024 needs a permission. With systemd, add `AmbientCapabilities=CAP_NET_BIND_SERVICE` to the `[Service]` part of the unit file.

### Read the files from the env

Keep the file paths out of the code, so each machine can use its own files. Add two optional getters to your `AppEnv`, then run `dart run build_runner build`:

```dart title="lib/config/env.dart"
/// the certificate file (PEM). Not set: plain HTTP.
String? get tlsCert;

/// the private key file (PEM) of the certificate
String? get tlsKey;
```

The getters hold only the keys. The config file makes the `TlsOptions`:

```dart title="lib/config/app.dart"
String? tlsCert = env.tlsCert;
String? tlsKey = env.tlsKey;

AppConfig appConfig = AppConfig(
  tls: tlsCert == null || tlsKey == null
      ? null
      : TlsOptions(certificatePath: tlsCert, keyPath: tlsKey),
  // ...
);
```

```bash title=".env"
TLS_CERT=/etc/letsencrypt/live/example.com/fullchain.pem
TLS_KEY=/etc/letsencrypt/live/example.com/privkey.pem
```

An empty value (`TLS_CERT=`) is the same as no key, so TLS stays off. Keep the two keys empty on your own machine, where you have no certificate.

### One port, one mode

A port with `tls` accepts only TLS. A plain HTTP client gets no answer, and the connection closes. A port without `tls` accepts only plain HTTP.

Dox does not send `http://` visitors to `https://`. See [Not included](#not-included).

### HTTP/2 and gRPC over TLS

Browsers use HTTP/2 only with TLS. Set `http2: true` together with `tls`, and browsers and gRPC clients use HTTP/2 with no proxy:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  http2: true,
  tls: TlsOptions(certificatePath: 'fullchain.pem', keyPath: 'privkey.pem'),
  // ...
);
```

The client selects the protocol in the TLS handshake (ALPN):

| `http2` | The server offers |
| --- | --- |
| `true` | `h2` and `http/1.1` |
| `false` | `http/1.1` only |

A client with no ALPN gets HTTP/1.1. `grpcurl` works without `-plaintext`. See [HTTP/2](http2.md) and [gRPC](grpc.md).

### reloadCertificate

A certificate has an end date, and a tool such as certbot writes a new one before that date. Call `reloadCertificate()` to use the new certificate without a restart:

```dart
await Dox().server.reloadCertificate();
```

- The method reads the same two files again.
- New connections get the new certificate. Open connections keep the old certificate until they close.
- One call is sufficient. All isolates of the process get the new certificate.
- If a file is bad, the method throws a `TlsException`. The server keeps the old certificate.
- If `tls` is off, the method throws a `StateError`.

Dox does not watch the files and has no signal for this. Your app decides when to call the method. This example calls it on `SIGHUP`:

```dart title="bin/server.dart"
Future<void> main() async {
  // ...
  await Dox().startServer();
  ProcessSignal.sighup.watch().listen(reloadCertificate);
}

Future<void> reloadCertificate(ProcessSignal signal) async {
  try {
    await Dox().server.reloadCertificate();
    Logger.info('The server has the new certificate');
  } on TlsException catch (error) {
    Logger.danger('The server keeps the old certificate: $error');
  }
}
```

Then let certbot send the signal after each renewal. With the systemd unit of [Keep it running](#keep-it-running):

```bash
certbot renew --deploy-hook "systemctl kill --signal=HUP dox"
```

Windows has no `SIGHUP`. There, call the method from a scheduled task or a timer in the server process, for example one time each day.

### Not included

- ACME: Dox does not get or renew a certificate (for example from Let's Encrypt). Use certbot or a similar tool, then call `reloadCertificate()`.
- Redirect from port 80: Dox does not send `http://` visitors to `https://`. Use a proxy for this.
- mTLS: Dox does not ask the client for a certificate.
- SNI: one port has one certificate. Dox does not select a certificate for each domain.

## HTTPS: put a proxy in front

A proxy gets and renews the certificate, does gzip and sends `http://` visitors to `https://`. Run Dox on a private port with plain HTTP, and put [Caddy](https://caddyserver.com) or nginx in front of it. When the proxy is on the same machine, set `APP_HOST=127.0.0.1`:

<ol class="dox-flow dox-flow--labels dox-flow--plain" aria-label="A proxy in front of Dox">
  <li><strong>Client</strong></li>
  <li data-via="HTTPS"><strong>Caddy or nginx</strong><span>TLS and gzip</span></li>
  <li data-via="HTTP" class="dox-flow__end"><strong>Dox</strong><span>a private port</span></li>
  <li><strong>Database</strong></li>
</ol>

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

gRPC needs HTTP/2 between the proxy and Dox. Set `http2: true` in `AppConfig` (see [HTTP/2](http2.md)). Without `tls`, Dox speaks h2c, so the proxy keeps the TLS. HTTP/1.1 and HTTP/2 use the same port.

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

## More than 8 CPU cores

The Dart VM runs 8 isolates at the same time by default. On a server with more than 8 cores, set `DART_VM_OPTIONS` to 2 MB for each isolate:

```dockerfile
# 16 cores: 16 x 2 = 32
ENV DART_VM_OPTIONS=--new_gen_semi_max_size=32
```

Dox prints a warning at the start when the value is too small. A larger value lets the app use more memory.

With [`isolateGroups`](#give-each-isolate-its-own-memory), this limit does not apply.

## Give each isolate its own memory

By default, all isolates share one heap and one garbage collector. Turn on `isolateGroups` to give each isolate its own:

```dart
AppConfig(
  appKey: env.appKey,
  flags: const CoreFlags(isolateGroups: true),
);
```

Each isolate then runs `main()` of `bin/server.dart` from the start. Use `Dox().isPrimary` for work that must run only one time:

```dart
void main() async {
  Dox().initialize(appConfig);

  if (Dox().isPrimary) {
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
  }

  await Dox().startServer();
}
```

Each isolate builds the config again, so read your settings and the app key from the env, not from command line arguments.

### Build

On Linux, the bundle of `dox build` works with no change. On macOS, also make a snapshot file with the name of the executable and `.aot`:

```bash
dart compile aot-snapshot bin/server.dart -o build/bundle/bin/server.aot
```

If Dox finds no file to start, it prints a warning and the isolates share memory.

### Memory for each isolate

The Dart VM keeps free memory pages for one isolate only. To keep them for all isolates, set 32 MB for each isolate:

```dockerfile
# 4 isolates: 4 x 32 = 128
ENV DART_VM_OPTIONS=--new_gen_semi_max_size=128,--new_gen_semi_initial_size=32,--new_gen_garbage_threshold=0
```

The app is faster and uses more memory, approximately 30 MB for each isolate.

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

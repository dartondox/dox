# Deployment

!!! danger "Never run production with `dart run`"
    `dart run` (and `dox serve`) uses the JIT compiler. It is made for
    development. It uses about 25x more memory at start (around 390 MB
    instead of 16 MB) and starts slower. Always build an AOT binary for
    production.

## Build

Compile the app to a native binary (AOT).

```bash
dox build
```

This makes a `build/` folder:

| File                 | What it is                                     |
| -------------------- | ---------------------------------------------- |
| `build/server`       | the native binary. No Dart SDK needed to run it |
| `build/db/`          | your migrations, run at start                  |
| `build/.env.example` | copy it to `build/.env`, or use env variables  |

`dox build` runs `build_runner` first (when your app uses it). Then it runs
`dart compile exe bin/server.dart -o build/server`. It exits with code 1 when
a step fails, so CI can stop.

Start the application.

```bash
cd build
./server
```

The binary reads `.env` and `db/` from the folder you start it in.
A real environment variable wins over the `.env` file.

## Docker

The `Dockerfile` in a new Dox app is a multi-stage build:

1. The `dart:stable` image builds the AOT binary.
2. The final image is `FROM scratch`. It holds only the Dart AOT runtime
   files (`/runtime/` from the dart image), your binary, `db/` and an empty
   `/tmp`. The image is about 11 MB.

The image has no `.env` file, so secrets stay out of it. Pass config as
environment variables.

```bash
docker build -t my-app .
docker run -p 3000:3000 -e APP_PORT=3000 -e APP_KEY=... -e DB_HOST=... my-app
```

Or use `env_file: .env` in `docker-compose.yml`.

## HTTPS: put a proxy in front

Do not serve HTTPS from Dart. TLS in Dart's `HttpServer` is slow (a known
Dart SDK issue). Dox has no `bindSecure`.

Run Dox on plain HTTP on a private port. Put [Caddy](https://caddyserver.com)
or nginx in front of it. The proxy does TLS, HTTP/2 and gzip.

Then tell Dox to trust the proxy, so `req.ip()` and `req.scheme()` show the
real client:

```dart
AppConfig(
  /// the proxy's IP, or a range like '10.0.0.0/8', or '172.16.0.0/12' for docker
  trustedProxies: <String>['127.0.0.1', '::1'],
);
```

- `req.ip()` reads `X-Forwarded-For`. Dox walks the list from the right and
  skips your proxies, so a fake value from the client is ignored.
- `req.scheme()` reads `X-Forwarded-Proto` (`http` or `https`).
  `req.isSecure()` is true for `https`.
- `trustedProxies` is empty by default. Then Dox ignores those headers,
  because any client can send them.
- `['*']` trusts everyone. Only use it when the app port is not reachable
  from outside.

### Caddy

Caddy gets a certificate for you and sets `X-Forwarded-For` and
`X-Forwarded-Proto`. Websockets work with no extra config.

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

## Keep it running

Dox uses all CPU cores by default (see [Isolate](isolate.md)).

- When a worker isolate dies, Dox prints the error and starts it again.
- When the main isolate dies, the process exits with a non-zero code.
  Let a supervisor restart it: `restart: unless-stopped` in Docker compose,
  or `Restart=always` in systemd.

```ini
# /etc/systemd/system/dox.service
[Service]
WorkingDirectory=/srv/app/build
ExecStart=/srv/app/build/server
EnvironmentFile=/srv/app/build/.env
Restart=always

[Install]
WantedBy=multi-user.target
```

## Many processes or machines

One Dox process already uses every core. You only need more processes to
run on more machines, or to restart one process without downtime.
Run each one on its own port (or machine) and list them in the proxy:

```nginx
upstream dox {
  server 10.0.0.11:3000;
  server 10.0.0.12:3000;
  keepalive 64;
}
```

Websocket rooms then need a shared adapter (like Redis), because each
process has its own memory.

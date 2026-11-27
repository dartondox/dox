---
title: "Deploy a Dart server to production with Dox"
date:
  created: 2026-11-27
authors:
  - dox
categories:
  - Guides
tags:
  - deploy
  - production
  - docker
slug: deploy-dart-server-to-production
description: "How to deploy a Dart server to production with Dox: a native binary, a small Docker image, config from the env, HTTPS, a health check and a clean shutdown."
---

# Deploy a Dart server to production with Dox

This post shows how to deploy a Dart server to production with Dox: a native binary, a small Docker image, config from the env, HTTPS, a health check and a clean shutdown.

<!-- more -->

Your team has a Dart API that works on a laptop.
Before you put it in front of users, you want to know how it is built, how it runs, how it starts again after a crash and how it stops.
This post answers those questions in the order of a real deploy, and each step links to the full docs page.
If you did not pick a framework yet, read [Dart backend frameworks: how to choose](dart-backend-frameworks-how-to-choose.md) first.

> **Key takeaways**
>
> - **One native binary.** `dox build` compiles the app ahead of time. The server needs no Dart SDK.
> - **A small image.** The final Docker image is `FROM scratch`: the Dart runtime and your app, with no shell.
> - **Config from the env.** No secret is in the image or in git. `dox env:check` stops a deploy with a missing key.
> - **HTTPS in two ways.** Put Caddy or nginx in front, or let Dox serve HTTPS with a certificate file.
> - **A clean stop.** On `SIGTERM`, Dox lets open requests finish before the process exits.

## What a production setup looks like

A Dox app in production is one process that uses every CPU core.
A proxy in front of it does the TLS work, and a supervisor starts the process again if it stops:

<ol class="dox-flow dox-flow--labels dox-flow--plain" aria-label="A proxy in front of Dox">
  <li><strong>Client</strong></li>
  <li data-via="HTTPS"><strong>Caddy or nginx</strong><span>TLS and gzip</span></li>
  <li data-via="HTTP" class="dox-flow__end"><strong>Dox</strong><span>a private port</span></li>
  <li><strong>Database</strong></li>
</ol>

You do not need a process manager that runs one worker for each core.
Dox starts one isolate for each core that the machine or the container gives it.

By default, the Dart VM runs only 8 isolates at the same time.
On a server with more than 8 cores, turn on `isolateGroups`.
See [Give each isolate its own memory](/latest/digging-deeper/deployment/#give-each-isolate-its-own-memory).

## 1. Build a native binary

Dart has two ways to run code.
`dart run` uses the JIT compiler, which is for development.
For production, compile the app [ahead of time](https://dart.dev/tools/dart-compile) (AOT) into a native binary:

```bash
dox build
```

The result is in `build/bundle/`:

| File | What it is |
| --- | --- |
| `bin/server` | the native binary. It needs no Dart SDK |
| `bin/queue` | the queue worker, when the app has one |
| `bin/schedule` | the scheduler, when the app has one |
| `lib/` | the native libraries, like the database drivers |
| `db/` | your migrations |

Start it from the bundle folder:

```bash
cd build/bundle
./bin/server
```

The start log must end with `(native)`:

```text
[server] Server started at http://[::]:3000 with 8 isolate (native)
```

!!! warning "Never run production with `dart run`"
    The JIT compiler uses much more memory at the start and starts slower. Always build with `dox build`. Do not use `dart compile exe`, because it does not include the native libraries.

`dox build` makes a binary for the system it runs on.
So build on Linux, in CI or in Docker, when the server is Linux.

## 2. Put it in a Docker image

A new Dox app has this `Dockerfile`.
The first stage builds the bundle with the Dart SDK.
The final stage holds only the Dart runtime and the bundle:

```dockerfile title="Dockerfile"
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

`FROM scratch` means the image has no shell, no package manager and no source code.
That keeps the image small, and there is less in it to attack or to patch.
The image of the blog API in the docs is approximately 17 MB.

Build it and run it:

```bash
docker build -t my-app .
docker run -p 3000:3000 --env-file .env my-app
```

The [Docker guide](/latest/guides/docker/) adds Postgres, a volume for uploads and a health check with Docker Compose.

## 3. Keep the config in the env

The image has no `.env` file, so no secret is in the image.
Give the config as environment variables, for example with `--env-file`, `env_file:` in Compose, or the secret store of your platform:

```ini title=".env"
APP_NAME=my_app
APP_ENV=production
APP_KEY=<output of dox key:generate>
APP_PORT=3000

DB_CONNECTION=postgres
DB_HOST=postgres
DB_NAME=my_app
DB_USERNAME=postgres
DB_PASSWORD=<a real password>
```

Three rules protect you here:

- **`APP_KEY` is your most important secret.** It encrypts cookies and signs tokens. Make one key for each environment with `dox key:generate`.
- **A bad key stops the app.** In production, Dox does not start with an empty key, a key that is not 32 characters, or a public sample key.
- **Check the env before a deploy.** `dox env:check` prints every missing or bad key and exits with code 1, so CI stops.

```bash
dox env:check
```

A real environment variable wins over a `.env` file.
See [Environments](/latest/guides/environments/) for dev, staging and production config.

## 4. Run the migrations

A new Dox app runs the migrations in `bin/server.dart`, before the server takes requests.
So a deploy with a new migration needs no extra step.

When you run many machines, run the migrations in one place only.
For example, run `dox migrate` one time in CI before the new version starts.
Then two machines can not migrate at the same time.
See [Migration](/latest/database/migration/).

## 5. Turn on HTTPS

You have two options.

### A proxy in front

A proxy gets and renews the certificate, does gzip and sends `http://` visitors to `https://`.
This is the best fit for most teams.
With [Caddy](https://caddyserver.com), the full config is four lines:

```text title="/etc/caddy/Caddyfile"
api.example.com {
	encode zstd gzip
	reverse_proxy 127.0.0.1:3000
}
```

Then tell Dox to trust the proxy, so `req.ip()` is the real client IP:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  // ...
  trustedProxies: <String>['127.0.0.1', '::1'],
);
```

Keep the app port private.
Set `APP_HOST=127.0.0.1` when the proxy is on the same machine.
For nginx, see [Deployment: put a proxy in front](/latest/digging-deeper/deployment/#https-put-a-proxy-in-front).

### HTTPS in Dox

Dox can also serve HTTPS with no proxy.
Give it a certificate file and a key file:

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

This fits a small server with one app.
Dox does not get or renew the certificate, so use [certbot](https://certbot.eff.org) or a similar tool.
Read [HTTPS without a proxy in Dox](https-without-a-proxy.md) for the details.

## 6. Add a health check

A load balancer, Docker or Kubernetes must know if the app can serve requests.
Add a health route with a database check:

```dart title="lib/routes/web.dart"
Route.health(
  '/health',
  checks: <String, HealthCheckFunction>{
    'database': () => QueryBuilder.query('select 1'),
  },
);
```

When all checks pass, the answer is 200:

```json
{"status": "ok", "checks": {"database": "ok"}}
```

When the database does not answer, the answer is 503.
Your platform then stops sending traffic to that machine.
See [Health check](/latest/digging-deeper/health-check/) for a cache check and the timeout.

## 7. Keep it running, and stop it cleanly

A supervisor must start the process again after a crash.
In Docker Compose, that is one line:

```yaml title="docker-compose.yml"
services:
  app:
    build: .
    env_file: .env
    restart: unless-stopped
```

With no Docker, use `Restart=always` in a systemd unit.
The guide [Deploy to a Linux server](/latest/guides/deploy-vps/) has the full unit file.

A deploy stops the old process.
On `SIGTERM`, Dox does these steps in every isolate:

1. It stops taking new connections.
2. It lets open requests finish, for 8 seconds at most by default.
3. It runs the `shutdown()` of every provider, so your own connections close.
4. It exits with code 0.

So a user with a request in progress gets an answer, not an error.
Set `shutdownTimeout` shorter than the time your platform waits before it kills the process:

| Platform | Waits |
| --- | --- |
| [`docker stop`](https://docs.docker.com/reference/cli/docker/container/stop/) | 10 seconds |
| [Kubernetes](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination) | 30 seconds |
| [Cloud Run](https://cloud.google.com/run/docs/container-contract#instance-shutdown) | 10 seconds |
| [Fly.io](https://fly.io/docs/reference/configuration/) | 5 seconds |
| systemd | 90 seconds |

The default of Dox is 8 seconds.
That is longer than the 5 seconds of Fly.io, so set a shorter time there, or set a longer `kill_timeout` in `fly.toml`:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  shutdownTimeout: Duration(seconds: 4),
  // ...
);
```

See [Graceful shutdown](/latest/digging-deeper/deployment/#graceful-shutdown).

## 8. Run the queue worker and the scheduler

One build has three binaries.
Run each one as its own process, from the same image:

| Process | Command |
| --- | --- |
| web server | `/app/bin/server` |
| queue worker | `/app/bin/queue work` |
| scheduler | `/app/bin/schedule work` |

In Compose, that is one more service with `command: ["/app/bin/queue", "work"]`.
Only the server runs the migrations, so start the server first.
A small app can run the jobs and the schedule inside the web server, with no extra process.
See [Background jobs and scheduled tasks in Dox](background-jobs-and-scheduled-tasks.md).

## 9. Read the logs and catch the errors

In production, a new Dox app writes one JSON line for each log to stdout.
Docker, systemd and every log service can read that format.
Set `LOG_LEVEL=warn` to keep only warnings and errors.

To send errors to your error tracker, extend `ExceptionHandler`:

```dart title="lib/app/exception_handler.dart"
class AppExceptionHandler extends ExceptionHandler {
  const AppExceptionHandler();

  @override
  void report(Object error, StackTrace stackTrace) {
    // send it to your error tracker
  }
}
```

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  exceptionHandler: const AppExceptionHandler(),
);
```

Every error that is not an HTTP exception goes to `report`.
In production, the client sees no error details.
See [Error handling](/latest/the-basic/errors/).

## Where to deploy

The same image runs on any platform that runs a container.
The docs have a guide for each of these:

| Target | Good for | Guide |
| --- | --- | --- |
| Your own Linux server | full control, low cost | [Deploy to a Linux server](/latest/guides/deploy-vps/) |
| Docker Compose | the app and Postgres on one machine | [Docker](/latest/guides/docker/) |
| Fly.io | a managed platform with volumes | [Deploy to Fly.io](/latest/guides/deploy-fly/) |
| Google Cloud Run | managed HTTPS, no server to manage | [Deploy to Google Cloud Run](/latest/guides/deploy-cloud-run/) |

## What Dox does not do for you

A team that checks a framework for production must also know the limits:

- **No hosted service.** You deploy the app yourself, on your server or your cloud.
- **No automatic certificates.** A proxy or certbot gets the certificate.
- **No backup tool.** Use `pg_dump`, `mysqldump` or the snapshots of your database service, and test a restore.
- **No deploy tool.** For a deploy with no downtime, run two processes behind the proxy and restart one at a time.

More gaps are on [What Dox does not have yet](/latest/concepts/status-and-roadmap/#what-dox-does-not-have-yet).

## Before your first deploy

Go through this short list.
The [production checklist](/latest/reference/production-checklist/) has the full one.

- The app runs from `dox build`, and the start line says `(native)`.
- `APP_KEY` is set, secret and different in each environment.
- `dox env:check` passes in CI.
- No `.env` file is in the image or in git.
- HTTPS is on, and the app port is private.
- `trustedProxies` is set when a proxy is in front.
- `/health` checks the database.
- `isolateGroups` is on when the server has more than 8 cores.
- A supervisor starts the process again.
- `shutdownTimeout` is shorter than the kill timeout of the platform.
- Uploads are on a volume or in S3.
- The database has backups, and you tested a restore.

## FAQ

### Do I need the Dart SDK on the server?

No.
`dox build` makes a native binary and puts the Dart runtime next to it in the image.
The SDK is only in the build stage.

### Do I need nginx in front of a Dart server?

No, but a proxy is the best fit for most teams.
Caddy or nginx gets the certificate, does gzip and sends `http://` visitors to `https://`.
Dox can serve HTTPS itself when you give it a certificate file.

### How many processes do I run?

One for each machine.
One Dox process uses every core, so you do not need one process for each core.
Run more processes only for more machines, or to restart with no downtime.

### Can a Dart server run on Kubernetes?

Yes.
It is a normal container: it reads config from the env, has a health route for probes and stops cleanly on `SIGTERM`.
Set `terminationGracePeriodSeconds` longer than `shutdownTimeout`.

## Summary

- Build with `dox build`, and run the binary in a `FROM scratch` image.
- Give the config through the env, and check it with `dox env:check`.
- Turn on HTTPS, add a health route and let a supervisor start the process again.

To see the full path with one app, follow [Build and deploy](/latest/tutorial/07-build-and-deploy/) in the tutorial.
If you do not have an app yet, start with [Build a Dart API with Dox](build-a-dart-api-with-dox.md).
For speed and memory numbers with the method, read [What makes Dox fast](what-makes-dox-fast.md).

---
icon: lucide/plane
---

# Deploy to Fly.io

Run the blog API on [Fly.io](https://fly.io) from the `Dockerfile` of your project, with SQLite on a volume or with Postgres.

!!! note
    These steps follow the Fly.io docs as of 2026-10-22. They were not run on Fly.io in CI.

## What you need

- A Fly.io account and the `fly` CLI (`fly auth login`).
- The blog API from the [tutorial](../tutorial/01-create-project.md), or any Dox app, with the `Dockerfile` of a new Dox app. See [Docker](docker.md) for how that file works.

## 1. Make the app on Fly.io

In the project folder:

```bash
fly launch --no-deploy
```

`fly launch` finds the `Dockerfile`, asks for an app name and a region, and writes `fly.toml`.
`--no-deploy` stops before the first deploy, so you can set the config first.

## 2. Write `fly.toml`

Replace the file with this one. Change `app` and `primary_region` to your values.

```toml title="fly.toml"
app = "blog-api"
primary_region = "ams"
# Dox waits up to 8 seconds for open requests on stop. Fly waits 5 by default.
kill_timeout = 10

[build]
  dockerfile = "Dockerfile"

# config that is not secret. Secrets come from `fly secrets set`.
[env]
  APP_ENV = "production"
  APP_PORT = "3000"
  DB_CONNECTION = "sqlite"
  DB_NAME = "/data/blog.sqlite"

[http_service]
  internal_port = 3000
  force_https = true
  # one machine, always on: the SQLite file is on its volume
  auto_stop_machines = "off"
  auto_start_machines = true
  min_machines_running = 1

  [[http_service.checks]]
    grace_period = "10s"
    interval = "30s"
    method = "GET"
    timeout = "5s"
    path = "/api/ping"

# the volume with the SQLite file
[mounts]
  source = "blog_data"
  destination = "/data"

[[vm]]
  memory = "256mb"
  cpu_kind = "shared"
  cpus = 1
```

- `internal_port` is the port the app listens on. Dox reads it from `APP_PORT` (or `PORT` when `APP_PORT` is not set). Keep the two the same.
- Values in `[env]` must be strings, so write `"3000"`, not `3000`.
- `[[vm]]` wins over `fly scale vm`. Each `fly deploy` sets the machine to these values.
- `kill_timeout`: keep it above `shutdownTimeout` of `AppConfig`. See [Graceful shutdown](../digging-deeper/deployment.md#graceful-shutdown).

## 3. Set the secrets

```bash
fly secrets set APP_KEY=<output of dox key:generate>
```

A secret is an environment variable on every machine of the app. `fly secrets list` shows the names, not the values.
A secret with the same name as an `[env]` key wins.

## 4. Choose a database

### SQLite on a volume

Make the volume that `[mounts]` asks for, in the same region:

```bash
fly volumes create blog_data --region ams --size 1
```

- One volume is attached to one machine only. Fly.io does not copy the data between volumes.
- So with SQLite, run exactly one machine.

### Postgres

Create a Managed Postgres cluster with `fly mpg create`, and attach it to the app:

```bash
fly mpg attach <cluster-id> --app blog-api
```

This sets the secret `DATABASE_URL`. It wins over the `DB_*` keys, for the app and the migrations. See [`DATABASE_URL`](../database/index.md#database_url).

Then delete `DB_CONNECTION` and `DB_NAME` from `[env]`, and delete the `[mounts]` section.
If the database asks for TLS, add `?sslmode=require` to the url with `fly secrets set DATABASE_URL=...`.

## 5. Deploy

```bash
fly deploy
```

`fly deploy` builds the image, makes the machine and starts it. The app runs the migrations at start. Then check that there is one machine:

```bash
fly scale show
```

If the count is more than 1 and you use SQLite, run `fly scale count 1`.

## Check it

```bash
curl https://blog-api.fly.dev/api/ping
```

```text
pong
```

```bash
fly status    # the machines and their state
fly logs      # the app logs, live
```

The first log lines after the first start:

```text
Migrating: 2023_07_16_131937700_create_users_table
Migrated: 2023_07_16_131937700_create_users_table
Migrating: 2026_10_22_205345_create_posts_table
Migrated: 2026_10_22_205345_create_posts_table
{"level":"INFO","name":"dox","message":"Server started at http://[::]:3000 with 1 isolate (native)", ...}
```

## HTTPS and the client IP

Fly.io ends TLS and sends plain HTTP to port 3000. `force_https = true` sends HTTP visitors to HTTPS.
To make `req.ip()` and `req.scheme()` show the real client, set `trustedProxies` in `AppConfig`.
The app port is reachable only through the Fly.io proxy, so `['*']` is safe here:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  // ...
  trustedProxies: <String>['*'],
);
```

See [Deployment: HTTPS](../digging-deeper/deployment.md#https-put-a-proxy-in-front).

## More CPU, more machines

Dox starts one isolate per CPU core it sees. On `cpus = 1` that is one isolate.

| You want | Do this |
| --- | --- |
| more speed on one machine | raise `cpus` in `[[vm]]` (and `memory`), then `fly deploy`. Dox uses the new cores by itself |
| more machines | use Postgres, then `fly scale count 2`. With SQLite, stay at one machine |
| a fixed number of isolates | set `APP_TOTAL_ISOLATE` in `[env]` |

Each machine is its own process. Socket.IO rooms and the memory cache are not shared between machines.

## Update the app

```bash
fly deploy
```

- Change config in `[env]` and run `fly deploy` again.
- `fly secrets set` restarts the machines with the new value. With `--stage` it only saves the value, and the next deploy uses it.
- The app runs new migrations at start.
- With one machine there is a short gap while it restarts.

## See also

- [Deployment](../digging-deeper/deployment.md) for the bundle and the `Dockerfile`
- [Environments](environments.md) for all env keys and `APP_KEY`
- [Docker](docker.md) for a health check binary and Docker Compose
- Fly.io docs: [fly.toml](https://fly.io/docs/reference/configuration/), [secrets](https://fly.io/docs/apps/secrets/), [volumes](https://fly.io/docs/volumes/overview/), [Managed Postgres](https://fly.io/docs/mpg/)

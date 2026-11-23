---
icon: lucide/plane
---

# Deploy to Fly.io

Run the blog API on [Fly.io](https://fly.io) from the `Dockerfile` of your project, with SQLite on a volume or with Postgres.

Fly.io builds the image from your `Dockerfile` and runs it with the config in `fly.toml`.

## What you need

- A Fly.io account and the `fly` CLI (`fly auth login`).
- The blog API from the [tutorial](../tutorial/01-create-project.md), or any Dox app, with the `Dockerfile` of a new Dox app. See [Docker](docker.md).

## 1. Make the app on Fly.io

In the project folder, make the app but do not deploy it yet:

```bash
fly launch --no-deploy
```

`fly launch` asks for an app name and a region, and writes `fly.toml`.

## 2. Write `fly.toml`

Replace `fly.toml` with this file. Change `app` and `primary_region` to your values:

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

- Keep `internal_port` the same as `APP_PORT`.
- Values in `[env]` must be strings, so write `"3000"`, not `3000`.
- Each `fly deploy` sets the machine to the values of `[[vm]]`.
- Keep `kill_timeout` above `shutdownTimeout` of `AppConfig`. See [Graceful shutdown](../digging-deeper/deployment.md#graceful-shutdown).

## 3. Set the secrets

`fly.toml` goes into git, so set secrets like `APP_KEY` with `fly secrets`:

```bash
fly secrets set APP_KEY=<output of dox key:generate>
```

A secret is an environment variable on every machine of the app. It wins over an `[env]` key with the same name.

## 4. Choose a database

### SQLite on a volume

For a small app, use SQLite. Make the volume that `[mounts]` asks for, in the same region:

```bash
fly volumes create blog_data --region ams --size 1
```

A volume is attached to one machine only. So with SQLite, run exactly one machine.

### Postgres

For more than one machine, use Postgres. Make a Managed Postgres cluster with `fly mpg create`, and attach it to the app:

```bash
fly mpg attach <cluster-id> --app blog-api
```

This sets the secret [`DATABASE_URL`](../database/index.md#database_url). It wins over the `DB_*` keys.

Then delete `DB_CONNECTION` and `DB_NAME` from `[env]`, and delete the `[mounts]` section. If the database asks for TLS, add `?sslmode=require` to the URL with `fly secrets set DATABASE_URL=...`.

## 5. Deploy

Build the image and start the machine. The app runs the migrations at start:

```bash
fly deploy
```

Make sure that there is one machine:

```bash
fly scale show
```

If the count is more than 1 and you use SQLite, run `fly scale count 1`.

## Check it

Call the API:

```bash
curl https://blog-api.fly.dev/api/ping
```

```text
pong
```

Look at the machines and the logs:

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
{"timestamp":"...","status":"info","message":"Server started at http://[::]:3000 with 1 isolate (native)","logger":{"name":"dox"},"source":"server"}
```

## HTTPS and the client IP

Fly.io handles HTTPS and sends plain HTTP to port 3000. Set `trustedProxies`, so `req.ip()` and `req.scheme()` show the real client. Only the Fly.io proxy can reach the app port, so `['*']` is safe here:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  // ...
  trustedProxies: <String>['*'],
);
```

## Scaling the app

Dox starts one isolate per CPU of the container:

| You want | Do this |
| --- | --- |
| more speed on one machine | raise `cpus` and `memory` in `[[vm]]`, then `fly deploy` |
| more machines | use Postgres, then `fly scale count 2`. With SQLite, stay at one machine |
| a fixed number of isolates | set `APP_TOTAL_ISOLATE` in `[env]` |

Machines do not share Socket.IO rooms or the memory cache.

## Updating the app

To send a new version, deploy again:

```bash
fly deploy
```

`fly secrets set` restarts the machines with the new value. With `--stage`, the next deploy uses the value. With one machine there is a short gap while it restarts.

## Next steps

- [Deployment](../digging-deeper/deployment.md): the bundle and HTTPS.
- [Environments](environments.md): all the env keys and `APP_KEY`.
- [Docker](docker.md): the `Dockerfile` and Docker Compose.
- [Fly.io docs](https://fly.io/docs/reference/configuration/): `fly.toml`, secrets, volumes and Managed Postgres.

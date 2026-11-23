---
icon: lucide/server-cog
---

# Deploy to a Linux server

Run the blog API on your own Linux server (a VPS), with systemd to keep it running and Caddy in front for HTTPS.

systemd starts the app again after a crash. Caddy gets the TLS certificate and sends the requests to the app:

```mermaid
flowchart LR
  client[Browser or app] -- "HTTPS :443" --> caddy[Caddy]
  caddy -- "HTTP 127.0.0.1:3000" --> dox["/opt/blog/bin/server (systemd)"]
```

## What you need

- A Linux server (Debian 12, Ubuntu 22.04 or newer) with SSH and `sudo`.
- A domain name. Its `A` (and `AAAA`) record points to the server.
- Docker on your machine, to build a Linux binary.
- The blog API from the [tutorial](../tutorial/01-create-project.md), or any Dox app.

## 1. Build the bundle for Linux

`dox build` makes a binary for the system it runs on. So build it in the `dart:stable` image, which is Debian:

```bash
docker run --rm -v "$PWD":/app -w /app dart:stable sh -c \
  'dart pub get && dart pub global activate dox &&
    /root/.pub-cache/bin/dox build'
```

The result is in `build/bundle/`:

```text
build/bundle/
  bin/server                         the AOT binary
  lib/dox_http_native-linux-*.so     the native HTTP server
  lib/dox_postgres_native-linux-*.so the native Postgres driver
  lib/dox_mysql_native-linux-*.so    the native MySQL driver
  lib/libsqlite3.so                  SQLite
  db/                                the migrations
  .env.example
```

Keep `bin/` and `lib/` together, because the binary loads the libraries from `../lib`.

!!! warning "Match the CPU of the server"
    Docker builds for the CPU of your machine. On a Mac with Apple silicon that is arm64, but most VPS plans are x86_64.
    For them, add `--platform linux/amd64` after `docker run`. Check the server with `uname -m`.

The container writes Linux paths into your `.dart_tool/`. So run `dart pub get` on your machine again before you use `dox serve`.

## 2. Make a user and the folders

Do not run the app as root. On the server, make a user `dox` that can not log in:

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin dox
sudo mkdir -p /opt/blog
sudo install -d -o dox -g dox /opt/blog/storage
```

The app uses these paths:

| Path | What it holds | Owner |
| --- | --- | --- |
| `/opt/blog` | the bundle (`bin/`, `lib/`, `db/`) | `root` |
| `/opt/blog/storage` | files the app writes (uploads, file cache) | `dox` |
| `/var/lib/blog` | the SQLite file. systemd makes it (see step 5) | `dox` |
| `/etc/blog.env` | config and secrets | `root`, mode `600` |

## 3. Copy the bundle to the server

Copy the bundle to a temp folder, then into `/opt/blog`:

```bash
rsync -a --delete --exclude storage/ \
    build/bundle/ you@server:/tmp/blog-bundle/
ssh you@server \
    'sudo rsync -a --delete --exclude storage/ /tmp/blog-bundle/ /opt/blog/'
```

## 4. Write the env file

Put the config and the secrets in `/etc/blog.env`:

```ini title="/etc/blog.env"
APP_NAME=blog
APP_ENV=production
APP_PORT=3000
APP_KEY=<output of dox key:generate>

DB_CONNECTION=sqlite
DB_NAME=/var/lib/blog/blog.sqlite
```

Only root may read the file:

```bash
sudo chown root:root /etc/blog.env
sudo chmod 600 /etc/blog.env
```

For Postgres, set `DB_CONNECTION=postgres` and add `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD` and `DB_NAME`. Or set one [`DATABASE_URL`](../database/index.md#database_url), like `postgres://app:secret@localhost:5432/blog`. It wins over the `DB_*` keys.

Do not put a `.env` file in `/opt/blog`. Keep all values in one place.

## 5. Write the systemd unit

The systemd unit starts the app at boot and starts it again after a crash:

```ini title="/etc/systemd/system/blog.service"
[Unit]
Description=Blog API (Dox)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=dox
Group=dox
# the binary reads db/ and .env from this folder
WorkingDirectory=/opt/blog
EnvironmentFile=/etc/blog.env
ExecStart=/opt/blog/bin/server
# start again after a crash, and after `kill`
Restart=always
RestartSec=2
# makes /var/lib/blog, owned by the user dox
StateDirectory=blog
# small safety settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
```

Start the app:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now blog
systemctl status blog
```

The app runs the migrations at start, before it takes requests. To change the number of isolates, set `APP_TOTAL_ISOLATE` in `/etc/blog.env`.

## 6. Close the app port

Only Caddy may talk to the app. Add this line to `/etc/blog.env`, so Dox listens on the local address only:

```ini title="/etc/blog.env"
APP_HOST=127.0.0.1
```

Also turn on a firewall, so that only SSH, HTTP and HTTPS are open:

```bash
sudo ufw default deny incoming
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## 7. Put Caddy in front

Install Caddy from its [install page](https://caddyserver.com/docs/install). Then write `/etc/caddy/Caddyfile`:

```text title="/etc/caddy/Caddyfile"
api.example.com {
	encode zstd gzip

	reverse_proxy 127.0.0.1:3000 {
		# while the app restarts, wait up to 10s for it instead of failing
		lb_try_duration 10s
		lb_try_interval 250ms
	}
}
```

Check the file and load it:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Caddy gets a TLS certificate for `api.example.com` by itself. Ports 80 and 443 must be open.

## 8. Trust Caddy in the app

Dox ignores the `X-Forwarded-*` headers of a proxy that is not in `trustedProxies`. List the local addresses:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  // ...
  trustedProxies: <String>['127.0.0.1', '::1'],
);
```

Now `req.ip()` is the real client IP and `req.scheme()` is https. Build and copy again after this change (steps 1 and 3).

## Check it

Call the API over HTTPS:

```bash
curl https://api.example.com/api/ping
```

```text
pong
```

Read the logs. In production the app writes one JSON line per log:

```bash
journalctl -u blog -f                     # follow new lines
journalctl -u blog --since "1 hour ago"   # the last hour
journalctl -u blog -b                     # since the last boot
```

The first lines after the first start look like this:

```text
Migrating: 2023_07_16_131937700_create_users_table
Migrated: 2023_07_16_131937700_create_users_table
Migrating: 2026_10_22_205345_create_posts_table
Migrated: 2026_10_22_205345_create_posts_table
{"timestamp":"...","status":"info","message":"Server started at http://127.0.0.1:3000 with 2 isolate (native)","logger":{"name":"dox"},"source":"server"}
```

`(native)` means the native HTTP server loaded.

From your machine, make sure that the app port is closed:

```bash
curl -m 5 http://api.example.com:3000/api/ping   # must time out
```

## Updating the app

1. Build a new bundle (step 1).
2. Copy it to the server (step 3). Keep the old one first, so you can go back:

    ```bash
    ssh you@server \
        'sudo rm -rf /opt/blog.prev && sudo cp -a /opt/blog /opt/blog.prev'
    rsync -a --delete --exclude storage/ \
        build/bundle/ you@server:/tmp/blog-bundle/
    ssh you@server \
        'sudo rsync -a --delete --exclude storage/ /tmp/blog-bundle/ /opt/blog/'
    ```

3. Restart the app. It runs new migrations at start.

    ```bash
    ssh you@server 'sudo systemctl restart blog'
    ```

4. Read the logs (`journalctl -u blog -n 20`) and run the check.

To go back, copy `/opt/blog.prev` to `/opt/blog` and restart. A migration that already ran stays.

A restart takes about one second, and Caddy waits for the app. For an update with no downtime, run two copies on two ports and list both in Caddy. See [Deployment: many processes](../digging-deeper/deployment.md#many-processes-or-machines).

## Next steps

- [Deployment](../digging-deeper/deployment.md): `dox build`, nginx and many processes.
- [Environments](environments.md): config per environment and `APP_KEY`.
- [Docker](docker.md): the app and Postgres in Docker Compose.
- [Native server](../digging-deeper/native-server.md): the native HTTP server.

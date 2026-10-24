# Deploy to a Linux server

Run the blog API on your own Linux server (a VPS), with systemd to keep it running and Caddy in front for HTTPS.

!!! note
    These steps follow the systemd and Caddy docs as of 2026-10-22. They were not run on a real VPS in CI.

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

`dox build` makes a native binary for the system it runs on. A binary built on macOS does not run on Linux.
So build it inside the `dart:stable` image (it is Debian):

```bash
docker run --rm -v "$PWD":/app -w /app dart:stable sh -c \
  'dart pub get && dart pub global activate dox ^3.0.0-alpha && /root/.pub-cache/bin/dox build'
```

The result is `build/bundle/`:

```text
build/bundle/
  bin/server                         the AOT binary
  lib/dox_http_native-linux-*.so     the native HTTP server
  lib/libsqlite3.so                  SQLite
  db/                                the migrations
  .env.example
```

The container shares your project folder. It writes Linux paths into `.dart_tool/`.
So run `dart pub get` on your machine again before you use `dox serve`.

Keep `bin/` and `lib/` together. The binary loads the libraries from `../lib`.
See [Deployment](../digging-deeper/deployment.md#build) for more about the bundle.

!!! warning "Match the CPU of the server"
    Docker builds for the CPU of your machine. On a Mac with Apple silicon that is `arm64`.
    Most VPS plans are `x86_64`. For them, add `--platform linux/amd64` after `docker run`.
    Check the server with `uname -m`.

## 2. Make a user and the folders

Run this on the server. The app runs as the user `dox`. This user can not log in.

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin dox
sudo mkdir -p /opt/blog
sudo install -d -o dox -g dox /opt/blog/storage
```

| Path | What it holds | Owner |
| --- | --- | --- |
| `/opt/blog` | the bundle (`bin/`, `lib/`, `db/`) | `root` |
| `/opt/blog/storage` | files the app writes (uploads, file cache) | `dox` |
| `/var/lib/blog` | the SQLite file. systemd makes it (see step 5) | `dox` |
| `/etc/blog.env` | config and secrets | `root`, mode `600` |

## 3. Copy the bundle to the server

```bash
rsync -a --delete --exclude storage/ build/bundle/ you@server:/tmp/blog-bundle/
ssh you@server 'sudo rsync -a --delete --exclude storage/ /tmp/blog-bundle/ /opt/blog/'
```

## 4. Write the env file

```ini title="/etc/blog.env"
APP_NAME=blog
APP_ENV=production
APP_PORT=3000
APP_KEY=<output of dox key:generate>

DB_CONNECTION=sqlite
DB_NAME=/var/lib/blog/blog.sqlite
```

```bash
sudo chown root:root /etc/blog.env
sudo chmod 600 /etc/blog.env
```

systemd reads this file as `root`, before it starts the app as `dox`. So `dox` does not need to read it.

For Postgres, set `DB_CONNECTION=postgres` and add `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD` and `DB_NAME`.
Or set one `DATABASE_URL`, like `postgres://app:secret@localhost:5432/blog`. It wins over the `DB_*` keys. See [`DATABASE_URL`](../database/index.md#database_url).
See [Environments](environments.md) for all keys.

!!! note "Which value wins"
    `Env.get()` reads a real environment variable first. It reads the `.env` file in the working folder only when the variable is not set.
    systemd gives the app the lines of `EnvironmentFile` as real environment variables.
    So `/etc/blog.env` wins over a `/opt/blog/.env`. Do not put a `.env` in `/opt/blog`, so there is only one place to look.

## 5. Write the systemd unit

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

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now blog
systemctl status blog
```

- `Restart=always`: when the main isolate dies, the process exits and systemd starts it again. See [Deployment: keep it running](../digging-deeper/deployment.md#keep-it-running).
- The app runs the migrations at start, before it takes requests.
- Dox starts one isolate per CPU core. Set `APP_TOTAL_ISOLATE` in `/etc/blog.env` to change it.

## 6. Close the app port

Caddy runs on the same machine. So let Dox listen on `127.0.0.1` only. Add this line to `/etc/blog.env`:

```ini title="/etc/blog.env"
APP_HOST=127.0.0.1
```

Now only programs on this machine can reach port `3000`.
Also turn on a firewall, so only SSH, HTTP and HTTPS are open:

```bash
sudo ufw default deny incoming
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## 7. Put Caddy in front

Install Caddy from its [install page](https://caddyserver.com/docs/install). The Debian package runs Caddy with systemd and reads `/etc/caddy/Caddyfile`.

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

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

- Caddy gets a TLS certificate for `api.example.com` by itself. Ports 80 and 443 must be open.
- `reverse_proxy` sets `X-Forwarded-For` and `X-Forwarded-Proto`.

## 8. Trust Caddy in the app

Dox ignores `X-Forwarded-For` and `X-Forwarded-Proto` until you list the proxy in `trustedProxies`.
Caddy talks to the app from the same server:

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  // ...
  trustedProxies: <String>['127.0.0.1', '::1'],
);
```

Now `req.ip()` is the real client IP and `req.scheme()` is `https`.
Build and copy again after this change (steps 1 and 3). See [Deployment: HTTPS](../digging-deeper/deployment.md#https-put-a-proxy-in-front).

## Check it

```bash
curl https://api.example.com/api/ping
```

```text
pong
```

Read the logs. In production the app writes one JSON line per log.

```bash
journalctl -u blog -f                     # follow new lines
journalctl -u blog --since "1 hour ago"   # the last hour
journalctl -u blog -b                     # since the last boot
```

The first lines after a start look like this:

```text
Migrating: 2026_10_22_205345_create_posts_table
Migrated: 2026_10_22_205345_create_posts_table
{"level":"INFO","name":"dox","message":"Server started at http://127.0.0.1:3000 with 2 isolate (native)", ...}
```

`(native)` means the native HTTP server loaded. When it does not load, the app stops at start and the error says why.

Check that the app port is closed. From your machine:

```bash
curl -m 5 http://api.example.com:3000/api/ping   # must time out
```

## Update the app

1. Build a new bundle (step 1).
2. Copy it to the server (step 3). Keep the old one first, so you can go back:

    ```bash
    ssh you@server 'sudo rm -rf /opt/blog.prev && sudo cp -a /opt/blog /opt/blog.prev'
    rsync -a --delete --exclude storage/ build/bundle/ you@server:/tmp/blog-bundle/
    ssh you@server 'sudo rsync -a --delete --exclude storage/ /tmp/blog-bundle/ /opt/blog/'
    ```

3. Restart the app. It runs new migrations at start.

    ```bash
    ssh you@server 'sudo systemctl restart blog'
    ```

4. Read the logs (`journalctl -u blog -n 20`) and run the check.

To go back: copy `/opt/blog.prev` to `/opt/blog` and restart. A migration that already ran is not undone.

!!! note "A restart is short, but not zero"
    A restart takes about one second. Dox does not wait for open requests when it stops, so a request that is running at that moment fails.
    New requests do not fail: `lb_try_duration` makes Caddy wait for the app to come back.
    For a real zero-downtime update, run two copies on two ports and list both in Caddy. See [Deployment: many processes](../digging-deeper/deployment.md#many-processes-or-machines).

## See also

- [Deployment](../digging-deeper/deployment.md) for `dox build`, Docker, nginx and many processes
- [Environments](environments.md) for config per environment and `APP_KEY`
- [Docker](docker.md) to run the app and Postgres with Docker Compose
- [Native server](../digging-deeper/native-server.md)

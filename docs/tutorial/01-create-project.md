---
icon: lucide/folder-plus
---

# Step 1: Create the project

In this step you make a new Dox project, start the dev server and call the first route.

## 1. Make the project

First install the `dox` command line tool. Then use it to make a project named `blog`:

```bash
dart pub global activate dox
dox create blog
cd blog
dart pub get
```

`dox create` downloads the [dox-sample](https://github.com/dartondox/dox-sample) template and names the package `blog`. So every import in this tutorial starts with `package:blog/`.

## 2. Look at the database settings

You do not need to change anything here. `dox create` made a `.env` file with a new random `APP_KEY`, and the template already uses SQLite:

```ini title=".env"
APP_PORT=3000
APP_KEY=<your new random key>

DB_CONNECTION=sqlite
DB_NAME=db/dox.sqlite
```

Dox makes the file `db/dox.sqlite` at the first start. SQLite does not use the other `DB_*` lines. The app reads these keys through the typed class in `lib/config/env.dart`. See [Environment variables](../digging-deeper/env.md).

!!! note "The folder must exist"
    Dox makes the database file when it is missing, but not its folder. If you set `DB_NAME=storage/blog.sqlite`, run `mkdir storage` first.

## 3. Start the server

Start the dev server:

```bash
dox s
```

`dox s` runs the code generator and the server. When you save a file in `lib/app/`, it hot reloads your code. When you change routes, config or other start-up code, it restarts the server.

The first start is slower, because it compiles the SQLite library. It also runs the migrations of the template. At the end you see a JSON log line with this message:

```text
Server started at http://[::]:3000 with 8 isolate (native)
```

The number of isolates is the number of CPU cores on your machine.

## Check it

Call the `ping` route from a second terminal:

```bash
curl -i http://localhost:3000/api/ping
```

You should see:

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
...

pong
```

The route is in `lib/routes/api.dart`. The `ApiRouter` has the prefix `api`, so `/ping` is served at `/api/ping`.

## Next

[Step 2: Model and migration](02-model-and-migration.md)

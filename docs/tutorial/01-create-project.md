---
icon: lucide/folder-plus
---

# Step 1: Create the project

This step makes a new Dox project, points it at SQLite, starts the dev server and calls the first route.

## 1. Install the CLI and make the project

```bash
dart pub global activate dox
dox create blog
cd blog
dart pub get
```

`dox create` downloads the [dox-sample](https://github.com/dartondox/dox-sample) template from GitHub and names the package `blog`.
So every import in this tutorial starts with `package:blog/`.


## 2. Use SQLite

`dox create` already made `.env` with a new random `APP_KEY`. The template already uses SQLite:

```ini title=".env"
APP_PORT=3000
APP_KEY=<your new random key>

DB_CONNECTION=sqlite
DB_NAME=db/dox.sqlite
```

Dox makes the file `db/dox.sqlite` at the first start. SQLite does not read the other `DB_*` lines.
The app reads these keys through the typed class in `lib/config/env.dart`. See [Environment variables](../digging-deeper/env.md).

!!! note "The folder must exist"
    Dox makes the database file when it is missing, but not its folder.
    If you set `DB_NAME=storage/blog.sqlite`, run `mkdir storage` first.

## 3. Start the server

```bash
dox s
```

`dox s` runs the code generator and the server. It restarts the server when you save a `.dart` file.
The first start is slower, because it compiles the SQLite library.
At the first start it also runs the migrations of the template.
The last line is a JSON log line with this message:

```text
Server started at http://[::]:3000 with 8 isolate (native)
```

Open it at `http://localhost:3000`. The number of isolates is the number of CPU cores.

## Check it

In a second terminal:

```bash
curl -i http://localhost:3000/api/ping
```

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
...

pong
```

The route is in `lib/routes/api.dart`. The `ApiRouter` has the prefix `api`, so `/ping` is served at `/api/ping`.

## Next

[Step 2: Model and migration](02-model-and-migration.md)

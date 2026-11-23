---
icon: lucide/folder-plus
---

# Step 1: Create the project

In this step you make a new Dox project, start the dev server and call the first route.

## 1. Make the project

Install the `dox` command line tool, then make a project with the name blog:

```bash
dart pub global activate dox
dox create blog
cd blog
dart pub get
```

The package name is blog, so each import in this tutorial starts with `package:blog/`.

## 2. Look at the database settings

You do not change anything here. `dox create` made a `.env` file with a new random app key, and the template uses SQLite:

```ini title=".env"
APP_PORT=3000
APP_KEY=<your new random key>

DB_CONNECTION=sqlite
DB_NAME=db/dox.sqlite
```

Dox makes the database file at the first start, but not its folder. If you set a path in a new folder, make the folder first. See [Environment variables](../digging-deeper/env.md).

## 3. Start the server

Start the dev server:

```bash
dox s
```

It runs the code generator and the server. It hot reloads your code in `lib/app/`, and it restarts the server when you change routes or config.

The first start is slower, because it compiles the SQLite library and runs the migrations of the template. At the end you see this log line:

```text
[server] Server started at http://[::]:3000 with 8 isolate (native)
```

The number of isolates is the number of CPU cores on your machine.

## Check it

Call the ping route from a second terminal:

```bash
curl -i http://localhost:3000/api/ping
```

You see:

```text
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
...

pong
```

The route is in `lib/routes/api.dart`. Its router has the prefix api, so `/ping` is at `/api/ping`.

## Next steps

- [Step 2: Model and migration](02-model-and-migration.md): make the posts table and its model.

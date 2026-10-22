# Step 1: Create the project

This step makes a new Dox project, points it at SQLite, starts the dev server and calls the first route.

## 1. Install the CLI and make the project

```bash
dart pub global activate dox 3.0.0-alpha.4
dox create blog
cd blog
dart pub get
```

`dox create` downloads the [dox-sample](https://github.com/dartondox/dox-sample) template from GitHub and names the package `blog`.
So every import in this tutorial starts with `package:blog/`.

!!! note "Check the versions"
    Open `pubspec.yaml`. Every Dox package must be `^3.0.0-alpha.4`.
    If the template has an older version, change it and run `dart pub get` again.

## 2. Use SQLite

Copy the example env file:

```bash
cp .env.example .env
```

The template already uses SQLite. These are the lines that matter:

```ini title=".env"
APP_PORT=3000
APP_KEY=KKep5qC6uHlAgrwaQTQewgMRSIqQnoj0

DB_CONNECTION=sqlite
DB_NAME=db/dox.sqlite
```

Dox makes the file `db/dox.sqlite` at the first start. The `db` folder is
in the template. The `DB_HOST`, `DB_PORT`, `DB_USERNAME` and `DB_PASSWORD`
lines are for Postgres and MySQL. SQLite does not read them.

!!! note "The folder must exist"
    Dox makes the database file when it is missing, but not its folder.
    If you set `DB_NAME=storage/blog.sqlite`, run `mkdir storage` first.

## 3. Start the server

```bash
dox s
```

`dox s` runs the code generator (`build_runner watch`) and `dart run bin/server.dart`.
It restarts the server when you save a `.dart` file.
The first start takes a little longer. It prints `Running build hooks...` while it compiles the SQLite library.

The last line is:

```text
Server started at http://127.0.0.1:3000 with 8 isolate (native)
```

The number of isolates is the number of CPU cores on your machine.

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

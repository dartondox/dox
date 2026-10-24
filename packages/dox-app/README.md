# dox_app

The example app of the Dox monorepo. It is not published to pub.dev (`publish_to: 'none'`).
Dox uses it to test all packages together.

To start a new project, use `dox create my_app` instead. See [Getting started](https://dartondox.dev/latest/).

## Development

```bash
dart pub get
cp .env.example .env
dox key:generate   # writes a new APP_KEY into .env
dox migrate
dox s
```

The app runs on the `APP_PORT` from `.env` (`3003` in `.env.example`).

## Production

```bash
dart pub get
cp .env.example .env
dox key:generate
dox build
cd build/bundle && ./bin/server
```

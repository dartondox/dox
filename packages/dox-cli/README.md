# dox

The `dox` command line tool. It creates projects and files, runs the dev server, builds for production and runs migrations.

[![pub package](https://img.shields.io/pub/v/dox.svg)](https://pub.dev/packages/dox)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/develop/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

```bash
dart pub global activate dox ^3.0.0-alpha
```

If your shell can not find `dox`, add `$HOME/.pub-cache/bin` to your `PATH`.

Dox 3.x is in alpha (`3.0.0-alpha.x`). `dox update` installs the newest version with the same major version, previews included.

## Use it

```bash
dox create my_app            # a new project from the starter template
cd my_app
dart pub get
cp .env.example .env
dox s                        # dev server, restarts when a file changes
```

## Commands

| Command | What it does |
| --- | --- |
| `dox create <name>` | create a new project |
| `dox serve` (or `dox s`) | start the dev server with `build_runner watch` |
| `dox build` | build the native (AOT) bundle into `build/bundle` |
| `dox make:controller <name> [-r]` | create a controller |
| `dox make:model <name> [-m]` | create a model, and with `-m` its migration |
| `dox make:dto <name>` | create a DTO (typed, checked input) |
| `dox make:job <name>` | create a queue job |
| `dox queue:work` | run the queue worker (also `queue:failed`, `queue:retry`, `queue:forget`, `queue:flush`) |
| `dox schedule:work` | run the scheduler (also `schedule:run`, `schedule:list`, `schedule:test`) |
| `dox make:migration <name> [--sql]` | create a Dart or SQL migration |
| `dox migration:run` (or `dox migrate`) | run new migrations |
| `dox migration:rollback [--step=N]` | undo the last batch, or the last N migrations |
| `dox migration:fresh [--seed]` | drop all tables, then run all migrations |
| `dox make:factory <model>` / `dox make:seeder <name>` | create a model factory or a seeder |
| `dox db:seed [--class=<name>]` | run the seeders |
| `dox key:generate` | make a new `APP_KEY` |
| `dox env:generate` / `dox env:check` | make or check the typed env class |
| `dox openapi:generate [dir]` | write `openapi.json` and `openapi.yaml` |

Run `dox help` for all commands.

## Documentation

- [Dox CLI](https://dartondox.dev/latest/digging-deeper/dox-cli/)
- [CLI reference](https://dartondox.dev/latest/reference/cli/)
- [API reference](https://pub.dev/documentation/dox/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/develop/LICENSE).

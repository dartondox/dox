---
icon: lucide/git-pull-request-arrow
---

# Contribute

This page shows how to work on Dox: set up the repo, run the tests, release packages and update the docs.

To send a change, fork the repo and open a pull request.

## Setting up local development

### 1. Clone the repo

```bash
git clone git@github.com:dartondox/dox.git
```

### 2. Install melos

The repo is a [Dart pub workspace](https://dart.dev/tools/pub/workspaces).
The melos config is in the root `pubspec.yaml` (under `melos:`). Use Dart 3.13 or newer.

```bash
dart pub global activate melos
```

### 3. Run melos bootstrap

It runs one `dart pub get` at the root. All local packages are linked.
There is one `pubspec.lock` for the whole repo.

```bash
melos bs
```

### 4. Useful commands

```bash
# Run all tests.
# Use `melos run test`. `melos test` is a built-in melos command.
melos run test

# Analyze and check format (same as CI)
melos run analyze
melos run format_check

# Build the dox cli executable (AOT).
# `dart compile exe` does not work: sqlite3 has a build hook. Use `dart build cli`.
cd packages/dox-cli
dart build cli --target bin/dox.dart --output build

# Run dox cli executable file
build/bundle/bin/dox --version
```

### If the project does not run

1. Remove `pubspec.lock` and `.dart_tool` at the root.
2. Remove any old `pubspec_overrides.yaml` and `pubspec.lock` in `packages/*` (left from melos 3).
3. Run `melos bs` again.

## Release (maintainers)

The `Release` GitHub workflow (`.github/workflows/publish.yaml`) publishes all public packages to pub.dev.
It runs when you push a tag like `v3.0.0-alpha.5`.
It uses pub.dev automated publishing, so it needs no token or secret.

### Steps

The full guide is [RELEASING.md](https://github.com/dartondox/dox/blob/main/RELEASING.md) in the repo. In short:

1. Bump every package with `bin/update_versions.sh`, and close the `## Unreleased` section of each `CHANGELOG.md`.
2. Merge the release PR, then push the tag `v<version>`. This publishes to pub.dev.
3. Release the matching `dox-sample` template.

The native packages (`dox_http_native`, `dox_postgres_native`, `dox_mysql_native`) are not in this repo.
See [Native packages](#native-packages) below.
`dox_orm`, `dox_migration`, `dox_socketio` and `dox_storage` are not in this repo either.
See [Packages in other repos](#packages-in-other-repos).

**New package only:** turn on pub.dev automated publishing for it first. See [One-time setup](#one-time-setup).
A new package must first exist on pub.dev, so publish its first version by hand with `dart pub publish`.

### What the workflow does

1. It checks that the tag (without `v`) is the root version, and that every package has this version.
   If not, it stops. Run `bin/update_versions.sh` and try again.
2. It gets the publish order from `bin/publish_order.py`.
   Each package comes after the sibling packages it depends on (`dependencies` and `dev_dependencies`).
   Packages with `publish_to: none` are left out. New packages are picked up by themselves.
3. It publishes each package in this order.
   After each one, it waits until `dart pub get` can find the new version.

To see the order on your machine:

```bash
python3 bin/publish_order.py
```

A package is skipped when its version is already on pub.dev.
So if a run fails halfway, fix the problem and click "Re-run jobs". It continues where it stopped.

### Dry run

Open Actions > Release > "Run workflow".
It runs `dart pub publish --dry-run` for every package and publishes nothing.
Warnings (for example a missing CHANGELOG entry) show as yellow warnings. They do not fail the run.

### One-time setup

Do this once for each published package, and for every new package before its first tag.
The list of packages is the output of `python3 bin/publish_order.py`.

On pub.dev:

1. Open `https://pub.dev/packages/<name>/admin`.
2. Under "Automated publishing", click "Enable publishing from GitHub Actions".
3. Repository: `dartondox/dox`.
4. Tag pattern: `v{{version}}`.
5. Tick "Require GitHub Actions environment" and set the environment to `pub.dev`.
6. Save.

On GitHub, in `dartondox/dox` > Settings > Environments, there must be an environment named `pub.dev`.
The publish job runs in it.
Optional: add yourself as a required reviewer, and allow only tags `v*`.

## Packages in other repos

| Package | Repo |
| --- | --- |
| `dox_orm`, `dox_migration` | [dartondox/dox-orm](https://github.com/dartondox/dox-orm) |
| `dox_socketio` | [dartondox/dox-socketio](https://github.com/dartondox/dox-socketio) |
| `dox_storage` | [dartondox/dox-storage](https://github.com/dartondox/dox-storage) |
| `dox_queue` | [dartondox/dox-queue](https://github.com/dartondox/dox-queue) |
| `dox_scheduler` | [dartondox/dox-scheduler](https://github.com/dartondox/dox-scheduler) |
| `dox_inertia` | [dartondox/dox-inertia](https://github.com/dartondox/dox-inertia) |
| `dox_view` | [dartondox/dox-view](https://github.com/dartondox/dox-view) |
| `dox_mailer` | [dartondox/dox-mailer](https://github.com/dartondox/dox-mailer) |

The packages here use them from pub.dev. The database tests (Postgres, MySQL, SQLite) run in `dox-orm`.

To work on one of them and Dox together:

1. Clone the repos next to the Dox repo: `../dox-orm`, `../dox-socketio`, `../dox-storage`.
   `ci/clone-siblings.sh` does this.
2. Add them to the root `pubspec_overrides.yaml` of the Dox repo. Git ignores this file.

    ```yaml
    dependency_overrides:
      dox_orm:
        path: ../dox-orm/packages/dox-orm
      dox_migration:
        path: ../dox-orm/packages/dox-migration
    ```

3. Run `dart pub get`.

The apps in `examples/` already use these clones (their `pubspec_overrides.yaml`), so clone them before you run an example.
In the other repo, a `pubspec_overrides.yaml` that points to `../dox/packages/...` uses your local Dox packages.

Each repo has its own version. Push a `v<version>` tag in that repo to release it.

## Native packages

The three native packages live in their own repos:

| Package | Repo |
| --- | --- |
| `dox_http_native` | [dartondox/dox-http-native](https://github.com/dartondox/dox-http-native) |
| `dox_postgres_native` | [dartondox/dox-postgres-native](https://github.com/dartondox/dox-postgres-native) |
| `dox_mysql_native` | [dartondox/dox-mysql-native](https://github.com/dartondox/dox-mysql-native) |

Dox uses them from pub.dev. Their build hooks download ready-built libraries, so you do not need Rust to work on Dox.

To work on a native package and Dox together:

1. Clone the package next to the Dox repo, like `../dox-http-native`.
2. Add it to the root `pubspec_overrides.yaml` of the Dox repo. Git ignores this file.

    ```yaml
    dependency_overrides:
      dox_http_native:
        path: ../dox-http-native
    ```

3. Run `dart pub get`.

Each native package is released from its own repo, with its own version.
Push a `v<version>` tag in that repo.
Its CI builds the libraries, uploads them, fills the hashes and publishes the package to pub.dev.
Then raise the version constraint in the Dox packages that use it.

## Docs

The docs site is https://dartondox.dev. It is built with MkDocs Material and
[mike](https://github.com/jimporter/mike). mike keeps one folder per version on the `gh-pages` branch.

| URL | What it is |
| --- | --- |
| `/3.x/...` | 3.x docs, built from `main` |
| `/latest/...` | a copy of the newest version (now 3.x) |
| `/2.x/...` | the old 2.x docs, built from the `v2.x` branch |
| `/` | redirects to `/latest/` |
| old links like `/the-basic/routing/` | redirect to `/latest/the-basic/routing/` |

### Write and preview

```bash
python3 -m venv .venv
.venv/bin/pip install mkdocs==1.6.1 mkdocs-material==9.7.7 mike==2.2.0
.venv/bin/mkdocs serve           # live preview of this branch
.venv/bin/mkdocs build --strict  # the same check as CI. Broken links fail.
```

### Deploy

- 3.x deploys by itself. The `Docs` workflow (`.github/workflows/docs.yaml`) runs on every push
  to `main` that changes `docs/`, `mkdocs.yml` or the workflow.
  It runs `mike deploy --update-aliases 3.x latest`.
- 2.x deploys by hand. Open Actions > Docs > "Run workflow", pick version `2.x`.
  It builds from the `v2.x` branch (change it with the `ref` input).
- After each deploy, the workflow writes small redirect pages for the old root links,
  the root `index.html`, a `404.html` and the `CNAME` file. So `dartondox.dev` and old links keep working.
- The workflow pushes with the built-in `GITHUB_TOKEN`. This works because `gh-pages` is not a protected branch.

### New major version

When 4.x starts, deploy 4.x with `mike deploy --update-aliases 4.x latest`. Keep a `v3.x`
branch, and add `3.x` to the workflow input, so 3.x can still be fixed.

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
```

### If the project does not run

1. Remove `pubspec.lock` and `.dart_tool` at the root.
2. Remove any old `pubspec_overrides.yaml` and `pubspec.lock` in `packages/*` (left from melos 3).
3. Run `melos bs` again.

## Release (maintainers)

The `Release` GitHub workflow (`.github/workflows/publish.yaml`) publishes one package to pub.dev.
Each package has its own version and its own tag, like `dox_builder-v3.1.4` (`<package>-v<version>`).
It uses pub.dev automated publishing, so it needs no token or secret.

### Steps

The full guide is [RELEASING.md](https://github.com/dartondox/dox/blob/main/RELEASING.md) in the repo. In short, for each package that changed:

1. Run `bin/bump.sh <package> <version>`. It sets the version of that package only.
   If the package needs a newer sibling, raise that constraint by hand.
   Close the `## Unreleased` section of its `CHANGELOG.md`.
2. Merge the release PR, then push the tag `<package>-v<version>`. This publishes that package to pub.dev.
   Release in dependency order: `dox_annotation`, `dox_cache`, `dox_builder`, `dox_core`.
3. Release the matching `dox-sample` template.

A builder-only fix needs a `dox_builder` release only. It does not need a `dox_core` release.

The native packages (`dox_http_native`, `dox_postgres_native`, `dox_mysql_native`) are not in this repo.
See [Native packages](#native-packages) below.
`dox_orm`, `dox_migration`, `dox_socketio`, `dox_storage`, `dox_queue`, `dox_queue_database`, `dox_scheduler`, `dox_inertia`, `dox_view` and `dox_mailer` are not in this repo either.
See [Packages in other repos](#packages-in-other-repos).

**New package only:** turn on pub.dev automated publishing for it first. See [One-time setup](#one-time-setup).
A new package must first exist on pub.dev, so publish its first version by hand with `dart pub publish`.

### What the workflow does

1. It reads the package name and the version from the tag.
   It stops with an error for an unknown package or a bad version.
2. It checks that the version in `packages/<folder>/pubspec.yaml` is the tag version.
   If not, it stops. Run `bin/bump.sh <package> <version>` and try again.
3. It runs the tests. They must pass.
   Then it checks that the sibling packages it needs are on pub.dev. If not, it stops: "release <dep> first".
4. It checks that one package with a dry run, then publishes it.

A tag for a version that is already on pub.dev is skipped.
So if a run fails, fix the problem and click "Re-run jobs".

To see the packages in publish order on your machine:

```bash
python3 bin/publish_order.py
```

### Dry run

Open Actions > Release > "Run workflow".
Pick one package, or `all`. It runs `dart pub publish --dry-run` and publishes nothing.
Warnings (for example a missing CHANGELOG entry) show as yellow warnings. They do not fail the run.

### One-time setup

Do this once for each published package, and for every new package before its first tag.
The list of packages is the output of `python3 bin/publish_order.py`.

On pub.dev:

1. Open `https://pub.dev/packages/<name>/admin`.
2. Under "Automated publishing", click "Enable publishing from GitHub Actions".
3. Repository: `dartondox/dox`.
4. Tag pattern: `<package>-v{{version}}`, like `dox_core-v{{version}}`. Each package has its own pattern.
5. Tick "Require GitHub Actions environment" and set the environment to `pub.dev`.
6. Save.

On GitHub, in `dartondox/dox` > Settings > Environments, there must be an environment named `pub.dev`.
The publish job runs in it.
Optional: add yourself as a required reviewer, and allow only the tags `dox_annotation-v*`, `dox_builder-v*`, `dox_cache-v*` and `dox_core-v*`.

## Packages in other repos

| Package | Repo |
| --- | --- |
| `dox` (the CLI) | [dartondox/dox-cli](https://github.com/dartondox/dox-cli) |
| `dox_orm`, `dox_migration`, `dox_cache_database` | [dartondox/dox-orm](https://github.com/dartondox/dox-orm) |
| `dox_auth` | [dartondox/dox-auth](https://github.com/dartondox/dox-auth) |
| `dox_openapi` | [dartondox/dox-openapi](https://github.com/dartondox/dox-openapi) |
| `dox_validation` | [dartondox/dox-validation](https://github.com/dartondox/dox-validation) |
| `dox_socketio` | [dartondox/dox-socketio](https://github.com/dartondox/dox-socketio) |
| `dox_storage` | [dartondox/dox-storage](https://github.com/dartondox/dox-storage) |
| `dox_queue`, `dox_queue_database` | [dartondox/dox-queue](https://github.com/dartondox/dox-queue) |
| `dox_scheduler` | [dartondox/dox-scheduler](https://github.com/dartondox/dox-scheduler) |
| `dox_inertia` | [dartondox/dox-inertia](https://github.com/dartondox/dox-inertia) |
| `dox_view` | [dartondox/dox-view](https://github.com/dartondox/dox-view) |
| `dox_mailer` | [dartondox/dox-mailer](https://github.com/dartondox/dox-mailer) |

The packages here use them from pub.dev. The database tests (Postgres, MySQL, MariaDB, SQLite) run in `dox-orm`.
`dox_core` uses `dox_openapi` and `dox_validation`.
CI in this repo uses their newest code: `ci/clone-siblings.sh`, then `ci/use-siblings.sh`.

To work on one of them and Dox together:

1. Clone the repos next to the Dox repo, like `../dox-orm`.
   `ci/clone-siblings.sh` clones `dox-orm`, `dox-auth`, `dox-openapi`, `dox-validation`, `dox-socketio`, `dox-storage`, `dox-queue`, `dox-scheduler` and `dox-cli`.
   Clone `dox-mailer`, `dox-view` and `dox-inertia` by hand when you need them.
2. Add them to the root `pubspec_overrides.yaml` of the Dox repo. Git ignores this file.
   For `dox_openapi` and `dox_validation`, `ci/use-siblings.sh` writes this file for you.

    ```yaml
    dependency_overrides:
      dox_openapi:
        path: ../dox-openapi
      dox_validation:
        path: ../dox-validation
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
| `/` | redirects to `/latest/` |
| old links like `/the-basic/routing/` | redirect to `/latest/the-basic/routing/` |

### Write and preview

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-docs.txt
.venv/bin/mkdocs serve           # live preview of this branch
.venv/bin/mkdocs build --strict  # the same build as CI. Broken links fail.
```

`hooks/docs_hooks.py` runs during the build. It makes the changelog page from `packages/*/CHANGELOG.md`, and writes `llms.txt` and `llms-full.txt`.

The `Docs check` workflow (`.github/workflows/docs-check.yaml`) runs on every pull request that changes the docs. It runs three checks:

- `mkdocs build --strict`
- a spell check: `codespell docs --skip "*.svg,*.png,*.ico,*.css,*.js" --ignore-words .codespell-ignore`
- `ci/check-no-tabs.sh`: the docs must not use content tabs

### Deploy

- 3.x deploys with each release. The `Docs` workflow (`.github/workflows/docs.yaml`) runs on a
  `dox_core-v<version>` tag, the same tag that publishes `dox_core`. So docs for a feature that is not released yet stay off the site.
  It runs `mike deploy --update-aliases 3.x latest`.
- To deploy the docs only (a typo fix, or the docs of a package from another repo that was just released),
  push a `docs-v<version>` tag on `main`, like `git tag docs-v3.0.1-1 && git push origin docs-v3.0.1-1`.
  It publishes no package and runs no tests.
- After each deploy, the workflow writes small redirect pages for the old root links,
  the root `index.html`, a `404.html` and the `CNAME` file. So `dartondox.dev` and old links keep working.
- The workflow pushes with the built-in `GITHUB_TOKEN`. This works because `gh-pages` is not a protected branch.

### New major version

When 4.x starts, deploy 4.x with `mike deploy --update-aliases 4.x latest`. Keep a `v3.x`
branch, and add `3.x` to the workflow input, so 3.x can still be fixed.

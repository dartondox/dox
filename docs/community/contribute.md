---
icon: lucide/git-pull-request-arrow
---

# Contribute

This page shows how to work on Dox: set up the repo, run the tests, release packages and update the docs.

To send a change, fork the repo and open a pull request. The release parts are for maintainers.

## Setting up local development

### 1. Clone the repo

```bash
git clone git@github.com:dartondox/dox.git
```

### 2. Install melos

The repo is a [Dart pub workspace](https://dart.dev/tools/pub/workspaces). Melos runs the commands for all packages, with its config in the root `pubspec.yaml`. You need Dart 3.13 or newer.

```bash
dart pub global activate melos
```

### 3. Run melos bootstrap

This gets the packages at the root and links all local packages:

```bash
melos bs
```

### 4. Run the tests and checks

Run the checks of CI before you open a pull request:

```bash
# Run all tests (not `melos test`, a built-in melos command)
melos run test

# Analyze and check format (same as CI)
melos run analyze
melos run format_check
```

### If the project does not run

If `melos bs` fails or the packages do not resolve, start clean:

1. Remove `pubspec.lock` and `.dart_tool` at the root.
2. Remove any old `pubspec_overrides.yaml` and `pubspec.lock` in `packages/*`.
3. Run `melos bs` again.

## Release (maintainers)

The Release workflow (`.github/workflows/publish.yaml`) publishes one package to pub.dev with automated publishing. Each package has its own version and its own tag, in the form `<package>-v<version>`.

### Steps

The full guide is [RELEASING.md](https://github.com/dartondox/dox/blob/main/RELEASING.md) in the repo. In short, for each package that changed:

1. Run `bin/bump.sh <package> <version>`. It sets the version of that package only. Raise the constraint of a newer sibling by hand. Then close the Unreleased section of its `CHANGELOG.md`.
2. Merge the release PR, then push the tag `<package>-v<version>`. This publishes that package to pub.dev. Release in dependency order: `dox_annotation`, `dox_cache`, `dox_builder`, `dox_core`.
3. Release the matching `dox-sample` template.

A fix in the builder needs only a `dox_builder` release. Many packages are in other repos. See [Packages in other repos](#packages-in-other-repos) and [Native packages](#native-packages).

For a new package, publish the first version by hand with `dart pub publish`. Then turn on automated publishing for it. See [One-time setup](#one-time-setup).

### What the workflow does

1. It reads the package name and the version from the tag. It stops with an error for an unknown package or a bad version.
2. It checks that the version in `packages/<folder>/pubspec.yaml` is the tag version. If not, it stops, so run `bin/bump.sh <package> <version>` and try again.
3. It runs the tests, and they must pass. Then it checks that the sibling packages it needs are on pub.dev. If not, it stops with "release <dep> first".
4. It checks that one package with a dry run, then publishes it.

The workflow skips a version that is already on pub.dev. So if a run fails, fix the problem and click "Re-run jobs".

To see the packages in publish order on your machine:

```bash
python3 bin/publish_order.py
```

### Dry run

To check a release with no publish, open Actions > Release > "Run workflow" and pick one package, or all. It runs `dart pub publish --dry-run`. Warnings show in yellow and do not fail the run.

### One-time setup

Do this once for each published package, and for every new package before its first tag. `python3 bin/publish_order.py` lists the packages.

On pub.dev:

1. Open `https://pub.dev/packages/<name>/admin`.
2. Under "Automated publishing", click "Enable publishing from GitHub Actions".
3. Repository: `dartondox/dox`.
4. Tag pattern: `<package>-v{{version}}`, like `dox_core-v{{version}}`. Each package has its own pattern.
5. Tick "Require GitHub Actions environment" and set the environment to `pub.dev`.
6. Save.

On GitHub, in `dartondox/dox` > Settings > Environments, there must be an environment named `pub.dev`, because the publish job runs in it. Optional: add yourself as a required reviewer, and allow only the tags `dox_annotation-v*`, `dox_builder-v*`, `dox_cache-v*` and `dox_core-v*`.

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

The packages in this repo use them from pub.dev. `dox_core` uses `dox_openapi` and `dox_validation`. The database tests run in dox-orm. CI in this repo tests with their newest code: it runs `ci/clone-siblings.sh`, then `ci/use-siblings.sh`.

To work on one of them and Dox together:

1. Clone the repos next to the Dox repo, like `../dox-orm`. `ci/clone-siblings.sh` clones `dox-orm`, `dox-auth`, `dox-openapi`, `dox-validation`, `dox-socketio`, `dox-storage`, `dox-queue`, `dox-scheduler` and `dox-cli`.
   Clone `dox-mailer`, `dox-view` and `dox-inertia` by hand when you need them.
2. Add them to the root `pubspec_overrides.yaml` of the Dox repo. Git ignores this file. For `dox_openapi` and `dox_validation`, `ci/use-siblings.sh` writes it for you.

    ```yaml
    dependency_overrides:
      dox_openapi:
        path: ../dox-openapi
      dox_validation:
        path: ../dox-validation
    ```

3. Run `dart pub get`.

The apps in `examples/` use these clones, so clone them before you run an example. In the other repo, a `pubspec_overrides.yaml` that points to `../dox/packages/...` uses your local Dox packages.

Each of these repos has its own version. To release one, push a `v<version>` tag in that repo.

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

Each native package is released from its own repo, with its own version. Push a `v<version>` tag in that repo. Its CI builds the libraries, uploads them, fills the hashes and publishes the package to pub.dev. Then raise the version constraint in the Dox packages that use it.

## Docs

The docs site is https://dartondox.dev. It is built with MkDocs Material and [mike](https://github.com/jimporter/mike), which keeps one folder per version on the `gh-pages` branch.

| URL | What it is |
| --- | --- |
| `/<version>/...` | the docs of one version, built from `main` |
| `/latest/...` | a copy of the newest version |
| `/` | redirects to `/latest/` |
| old links like `/the-basic/routing/` | redirect to `/latest/the-basic/routing/` |

### Write and preview

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-docs.txt
.venv/bin/mkdocs serve           # live preview of this branch
.venv/bin/mkdocs build --strict  # the same build as CI. Broken links fail.
```

The build hook `hooks/docs_hooks.py` writes `llms.txt` and `llms-full.txt`. Each pull request that changes the docs runs the Docs check workflow, with three checks:

- `mkdocs build --strict`
- a spell check: `codespell docs --skip "*.svg,*.png,*.ico,*.css,*.js" --ignore-words .codespell-ignore`
- `ci/check-no-tabs.sh`: the docs must not use content tabs

### Deploy

- The docs deploy with each release. The `Docs` workflow (`.github/workflows/docs.yaml`) runs on a `dox_core-v<version>` tag, the same tag that publishes `dox_core`, and runs `mike deploy`. So docs for a feature that is not released yet stay off the site.
- To deploy the docs only, push a `docs-v<version>` tag on `main`. It publishes no package and runs no tests.
- After each deploy, the workflow writes the redirect pages, the root `index.html`, a `404.html` and the `CNAME` file.
- The workflow pushes with the built-in `GITHUB_TOKEN`, so `gh-pages` must not be a protected branch.

## Next steps

- [Status and roadmap](../concepts/status-and-roadmap.md): the state and the tests of each package.
- [Showcase](showcase.md): apps built with Dox.

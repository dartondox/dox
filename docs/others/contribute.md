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
# Run all tests (not dox_orm and not dox_mysql_native).
# Use `melos run test`. `melos test` is a built-in melos command.
melos run test

# Analyze and check format (same as CI)
melos run analyze
melos run format_check

# Run tests for dox_orm with postgres, mysql or sqlite
DB_PORT=5432 melos run test_pg
DB_USER=dox DB_PORT=3306 melos run test_mysql
melos run test_sqlite

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
It runs when you push a tag like `v3.0.0-alpha.4`.
It uses pub.dev automated publishing, so it needs no token or secret.

### Steps

1. Set the new version in the root `pubspec.yaml`, for example `version: 3.0.0-alpha.4`.
2. Run the script.
   ```bash
   bash bin/update_versions.sh
   ```
   It copies the version to every `packages/*/pubspec.yaml`.
   It sets every sibling dependency to `^3.0.0-alpha.4`.
   It also writes the CLI version constant in `packages/dox-cli/lib/src/version.dart`.
3. Add a `## 3.0.0-alpha.4` entry to the `CHANGELOG.md` of each package. pub.dev warns when it is missing.
4. **New package only:** turn on pub.dev automated publishing for it. See [One-time setup](#one-time-setup).
   If you skip this, the Release workflow fails on this package.
   A new package must first exist on pub.dev, so publish its first version by hand with `dart pub publish`.
5. Commit and push.
   ```bash
   git commit -am "release 3.0.0-alpha.4"
   git push
   ```
6. Wait until the `Test` workflow is green for this commit. The Release workflow does not run the tests.
7. Tag and push the tag. This starts the publish.
   ```bash
   git tag v3.0.0-alpha.4
   git push origin v3.0.0-alpha.4
   ```

### What the workflow does

1. It checks that the tag (without `v`) is the root version, and that every package has this version.
   If not, it stops. Run `bin/update_versions.sh` and try again.
2. It gets the publish order from `bin/publish_order.py`.
   The script reads every `packages/*/pubspec.yaml`.
   It puts each package after the sibling packages it depends on (`dependencies` and `dev_dependencies`).
   Packages with `publish_to: none` (like `dox_app`) are left out.
   A new package is picked up by itself.
3. It publishes each package in this order.
   After each one, it waits until `dart pub get` can find the new version. Then the next package can depend on it.

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
The old `PUB_CREDENTIALS` secret is not used any more.

## Docs

The docs site is https://dartondox.dev. It is built with MkDocs Material and
[mike](https://github.com/jimporter/mike). mike keeps one folder per version on the `gh-pages` branch.

| URL | What it is |
| --- | --- |
| `/3.x/...` | 3.x docs, built from `develop` |
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
  to `develop` that changes `docs/`, `mkdocs.yml` or the workflow.
  It runs `mike deploy --update-aliases 3.x latest`.
- 2.x deploys by hand. Open Actions > Docs > "Run workflow", pick version `2.x`.
  It builds from the `v2.x` branch (change it with the `ref` input).
- After each deploy, the workflow writes small redirect pages for the old root links,
  the root `index.html`, a `404.html` and the `CNAME` file. So `dartondox.dev` and old links keep working.
- The workflow pushes with the built-in `GITHUB_TOKEN`. This works because `gh-pages` is not a protected branch.

### Why mike

- Old docs stay online at `/2.x/`, and readers switch with the version menu.
- Each version is built once from its own branch. A new deploy does not touch the other versions.
- Old links from before versioning are kept with redirect pages, so search results and blog posts still work.

### New major version

When 4.x starts, deploy 4.x with `mike deploy --update-aliases 4.x latest`. Keep a `v3.x`
branch, and add `3.x` to the workflow input, so 3.x can still be fixed.

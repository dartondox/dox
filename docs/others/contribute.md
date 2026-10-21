# Contribute 

Want to contribute? Great! Fork the repo and create PR to us.

# Setting up local development

#### 1. Clone repo

```py
git clone git@github.com:dartondox/dox.git
```

#### 2. Install melos if not installed 

This repo uses melos 3. Melos 7 and newer use a different config.

```py
dart pub global activate melos 3.4.0
```

#### 3. Run melos bootstrap

```py
melos bs
```

#### 4. Other Useful Commands

```py
# Run all tests (not dox_orm)
melos run test --no-select

# Analyze and check format (same as CI)
melos run analyze --no-select
dart format --output=none --set-exit-if-changed .

# Run tests for dox_orm with postgres, mysql or sqlite
DB_PORT=5432 melos run test_pg
DB_USER=dox DB_PORT=3306 melos run test_mysql
melos run test_sqlite

# Generate dox cli executable file
cd packages/dox-cli
dart compile exe bin/dox.dart -o bin/dox

# Run dox cli executable file
bin/dox --version
```

#### If failed to run the project

- remove all pubspec.lock files
- and run `melos bs` again

# Release (maintainers)

All public packages are published to pub.dev by the `Release` GitHub workflow
(`.github/workflows/publish.yaml`). It runs when you push a tag like `v3.0.0-alpha.1`.
It uses pub.dev automated publishing, so no token or secret is needed.

#### Steps

1. Set the new version in the root `pubspec.yaml`, for example `version: 3.0.0-alpha.1`.
2. Run the script. It copies the version to every package, to every sibling
   dependency (`^3.0.0-alpha.1`), and to the CLI version constant.
   ```py
   bash bin/update_versions.sh
   ```
3. Add a `## 3.0.0-alpha.1` entry to each package `CHANGELOG.md` (pub.dev warns if it is missing).
4. Commit and push.
   ```py
   git commit -am "release 3.0.0-alpha.1"
   git push
   ```
5. Wait until the `Test` workflow is green for this commit. The release workflow does not run the tests.
6. Tag and push the tag. This starts the publish.
   ```py
   git tag v3.0.0-alpha.1
   git push origin v3.0.0-alpha.1
   ```

The workflow first checks that the tag matches the root version and every package version.
Then it publishes in this order: `dox_annotation`, `dox_builder`, `dox_orm`,
`dox_query_builder`, `dox_migration`, `dox_core`, `dox_auth`, `dox_websocket`,
`dox_validation`, `dox_openapi`, `dox_storage`, `dox_cache`, `dox_socketio`, `dox`.
A package is skipped when that version is already on pub.dev. So if a run fails halfway,
fix the problem and click "Re-run jobs". It continues where it stopped.

#### Dry run

Open Actions > Release > "Run workflow". It runs `dart pub publish --dry-run` for every
package and publishes nothing. Warnings (for example local path overrides or a missing
CHANGELOG entry) are shown as yellow warnings and do not fail the run.

#### One-time setup

On pub.dev, for each package (`dox_annotation`, `dox_builder`, `dox_orm`,
`dox_query_builder`, `dox_migration`, `dox_core`, `dox_auth`, `dox_websocket`,
`dox_validation`, `dox_openapi`, `dox_storage`, `dox_cache`, `dox_socketio`, `dox`):

1. Open `https://pub.dev/packages/<name>/admin`.
2. Under "Automated publishing", click "Enable publishing from GitHub Actions".
3. Repository: `dartondox/dox`.
4. Tag pattern: `v{{version}}`.
5. Tick "Require GitHub Actions environment" and set the environment to `pub.dev`.
6. Save.

On GitHub, in `dartondox/dox` > Settings > Environments, create an environment named `pub.dev`.
Optional: add yourself as a required reviewer, and limit it to tags `v*`.
The old `PUB_CREDENTIALS` secret is no longer used.

# Docs

The docs site is https://dartondox.dev. It is built with MkDocs Material and
[mike](https://github.com/jimporter/mike). mike keeps one folder per version on the `gh-pages` branch.

| URL | What it is |
| --- | --- |
| `/3.x/...` | 3.x docs, built from `develop` |
| `/latest/...` | a copy of the newest version (now 3.x) |
| `/2.x/...` | the old 2.x docs, built from the `v2.x` branch |
| `/` | redirects to `/latest/` |
| old links like `/the-basic/routing/` | redirect to `/latest/the-basic/routing/` |

#### Write and preview

```py
python3 -m venv .venv
.venv/bin/pip install mkdocs==1.6.1 mkdocs-material==9.7.7 mike==2.2.0
.venv/bin/mkdocs serve           # live preview of this branch
.venv/bin/mkdocs build --strict  # the same check as CI. Broken links fail.
```

#### Deploy

- 3.x deploys by itself. The `Docs` workflow (`.github/workflows/docs.yaml`) runs on every push
  to `develop` that changes `docs/`, `mkdocs.yml` or the workflow.
  It runs `mike deploy --update-aliases 3.x latest`.
- 2.x deploys by hand. Open Actions > Docs > "Run workflow", pick version `2.x`.
  It builds from the `v2.x` branch (change it with the `ref` input).
- After each deploy, the workflow writes small redirect pages for the old root links,
  the root `index.html`, a `404.html` and the `CNAME` file. So `dartondox.dev` and old links keep working.
- The workflow pushes with `GITHUB_TOKEN`. If `gh-pages` is a protected branch, add a
  `PUSH_TO_PROTECTED_BRANCH` secret with a token that may push to it.

#### Why mike

- Old docs stay online at `/2.x/`, and readers switch with the version menu.
- Each version is built once from its own branch. A new deploy does not touch the other versions.
- Old links from before versioning are kept with redirect pages, so search results and blog posts still work.

#### New major version

When 4.x starts, deploy 4.x with `mike deploy --update-aliases 4.x latest`. Keep a `v3.x`
branch, and add `3.x` to the workflow input, so 3.x can still be fixed.

# Contribute 

Want to contribute? Great! Fork the repo and create PR to us.

# Setting up local development

#### 1. Clone repo

```py
git clone git@github.com:dartondox/dox.git
```

#### 2. Install melos if not installed 

```py
dart pub global activate melos
```

#### 3. Run melos bootstrap

```py
melos bs
```

#### 4. Other Useful Commands

```py
# Run all tests
melos run test

# Run tests for dox_query_builder with postgres
melos run test_query_builder_postgres

# Run tests for dox_query_builder with mysql
melos run test_query_builder_mysql

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
Then it publishes in this order: `dox_annotation`, `dox_builder`, `dox_query_builder`,
`dox_migration`, `dox_core`, `dox_auth`, `dox_websocket`, `dox`.
A package is skipped when that version is already on pub.dev. So if a run fails halfway,
fix the problem and click "Re-run jobs". It continues where it stopped.

#### Dry run

Open Actions > Release > "Run workflow". It runs `dart pub publish --dry-run` for every
package and publishes nothing. Warnings (for example local path overrides or a missing
CHANGELOG entry) are shown as yellow warnings and do not fail the run.

#### One-time setup

On pub.dev, for each package (`dox_annotation`, `dox_builder`, `dox_query_builder`,
`dox_migration`, `dox_core`, `dox_auth`, `dox_websocket`, `dox`):

1. Open `https://pub.dev/packages/<name>/admin`.
2. Under "Automated publishing", click "Enable publishing from GitHub Actions".
3. Repository: `dartondox/dox`.
4. Tag pattern: `v{{version}}`.
5. Tick "Require GitHub Actions environment" and set the environment to `pub.dev`.
6. Save.

On GitHub, in `dartondox/dox` > Settings > Environments, create an environment named `pub.dev`.
Optional: add yourself as a required reviewer, and limit it to tags `v*`.
The old `PUB_CREDENTIALS` and `PUSH_TO_PROTECTED_BRANCH` secrets are no longer used.

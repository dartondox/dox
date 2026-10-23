# Releasing Dox

This guide shows how to release a new Dox version to pub.dev.
All packages in `packages/` share one version, for example `3.0.0-alpha.5`.

## Why there are several tags

Three packages ship ready-built Rust libraries:

- `dox_http_native` (the HTTP server)
- `dox_postgres_native` (the Postgres driver)
- `dox_mysql_native` (the MySQL driver)

Each published package checks the library it downloads with a sha256 hash.
The hash only exists after the library is built.
A version on pub.dev can never change.
So the order is always:

1. Build the libraries (one tag per native package).
2. Write their hashes into the code.
3. Publish to pub.dev (the `v<version>` tag).

## Before you start

- `develop` has every change you want to ship, and CI is green.
- Each package with changes has a `## Unreleased` section at the top of its `CHANGELOG.md`.
- A package that was never published by the Release workflow needs automated publishing on pub.dev.
  Go to pub.dev → the package → Admin → Automated publishing → GitHub Actions.
  Use repo `dartondox/dox`, tag pattern `v{{version}}` and environment `pub.dev`.
  Without it, the Release workflow fails on that package.

In the steps below, replace `3.0.0-alpha.5` with the new version.

## 1. Bump the versions

```sh
git checkout -b release-3.0.0-alpha.5 origin/develop
```

1. Set `version: 3.0.0-alpha.5` in the root `pubspec.yaml`.
2. Run `bash bin/update_versions.sh`.
   It sets the version of every package, every sibling constraint, and the CLI version constant.
3. In every `packages/*/CHANGELOG.md`:
   - rename `## Unreleased` to `## 3.0.0-alpha.5`, or
   - if there is no `## Unreleased`, add `## 3.0.0-alpha.5` with "- Version bump only, to match the other packages."
4. Run `dart pub get` and `dart analyze --fatal-infos packages`.
5. Commit and push the branch.

## 2. Build the native libraries

Tag the release commit once for each native package:

```sh
for p in dox_http_native dox_postgres_native dox_mysql_native; do
  git tag $p-v3.0.0-alpha.5
  git push origin $p-v3.0.0-alpha.5
done
```

Each tag starts `.github/workflows/native.yaml`.
It builds macOS (arm64, x64), Linux (x64, arm64) and Windows (x64).
It uploads the 5 libraries and a `SHA256SUMS` file to a GitHub release with the tag name.

Wait until all three runs pass:

```sh
gh run list --workflow native.yaml --limit 3
```

## 3. Write the hashes into the code

```sh
for p in dox_http_native dox_postgres_native dox_mysql_native; do
  dart run bin/native_hashes.dart $p-v3.0.0-alpha.5
done
```

This fills the `_sha256` map in each `packages/dox-*-native/hook/build.dart`.
Commit and push.

If the hook needs a library with an empty map, it builds the library with cargo.
Users without Rust then fall back to `dart:io` and the Dart DB drivers.
So never publish with an empty map.

## 4. Merge the release PR

Open a PR from `release-3.0.0-alpha.5` into `develop`.
Wait for CI, then squash merge it.

## 5. Publish to pub.dev

Tag the merge commit on `develop`:

```sh
git checkout develop && git pull
git tag v3.0.0-alpha.5
git push origin v3.0.0-alpha.5
```

The tag starts `.github/workflows/publish.yaml` (the "Release" workflow).
It checks that the tag matches every package version.
Then it publishes the packages in dependency order (`bin/publish_order.py`).

If one package fails (for example, automated publishing is off):

1. Fix the cause.
2. Run `gh run rerun <run id> --failed`.

Packages that are already published are skipped.

To test without publishing, run the Release workflow by hand (workflow_dispatch).
That is a dry run only.

## 6. Release the project template

`dox create` copies a GitHub release of `dartondox/dox-sample` (branch `v3.x`).
It takes the newest release with the same major version as the CLI.

In `dox-sample`:

1. Set the `^3.0.0-alpha.5` versions in `pubspec.yaml` and `README.md`.
   Remove any `pubspec_overrides.yaml`.
2. Check it against pub.dev:
   ```sh
   dart pub get
   dart run build_runner build --delete-conflicting-outputs
   dart analyze
   ```
3. Commit and push `v3.x`.
4. Tag and release it. Keep it a pre-release while Dox is in alpha or beta:
   ```sh
   git tag v3.0.0-alpha.5 && git push origin v3.0.0-alpha.5
   gh release create v3.0.0-alpha.5 --prerelease
   ```
5. Test it end to end:
   ```sh
   dox create demo && cd demo
   dart pub get && cp .env.example .env
   dox s
   curl localhost:3000/ping   # pong
   ```

## 7. Check

- Every package shows the new version on pub.dev.
- The docs deploy from `develop` passed (the "Docs" workflow).
- `dox create` makes a project with the new version.

# Releasing Dox

This guide shows how to release a new Dox version to pub.dev.
All packages in `packages/` share one version, for example `x.y.z`.

## Native packages

The native packages are not released from this repo:

- `dox_http_native` (the HTTP server): [dartondox/dox-http-native](https://github.com/dartondox/dox-http-native)
- `dox_postgres_native` (the Postgres driver): [dartondox/dox-postgres-native](https://github.com/dartondox/dox-postgres-native)
- `dox_mysql_native` (the MySQL driver): [dartondox/dox-mysql-native](https://github.com/dartondox/dox-mysql-native)

Each one has its own version. To release one, push a `v<version>` tag in its repo.
Its CI builds the libraries, uploads them, fills the hashes and publishes the package to pub.dev.

When a Dox release needs a new native version, release the native package first.
Then raise its constraint (like `dox_http_native: ^x.y.z`) in the Dox packages that use it.

## Packages in other repos

These packages are not released from this repo either:

- `dox_orm` and `dox_migration`: [dartondox/dox-orm](https://github.com/dartondox/dox-orm). The two share one version.
- `dox_socketio`: [dartondox/dox-socketio](https://github.com/dartondox/dox-socketio)
- `dox_storage`: [dartondox/dox-storage](https://github.com/dartondox/dox-storage)
- `dox_queue`: [dartondox/dox-queue](https://github.com/dartondox/dox-queue)
- `dox_scheduler`: [dartondox/dox-scheduler](https://github.com/dartondox/dox-scheduler)
- `dox` (the CLI, also called `dox_cli`): [dartondox/dox-cli](https://github.com/dartondox/dox-cli). Its version is also in `lib/src/version.dart`. Set both before you push the tag.

Each repo has its own version. To release, push a `v<version>` tag in that repo.
Its Release workflow publishes to pub.dev.

`dox_socketio` and `dox_storage` depend on `dox_core`. When they need a new `dox_core`, release this repo first.
`dox_auth`, `dox_core` (dev) and the CLI depend on `dox_orm` or `dox_migration` from pub.dev.
When they need a new one, release `dox-orm` first, then raise the constraint here.

## Before you start

- `main` has every change you want to ship, and CI is green.
- Each package with changes has a `## Unreleased` section at the top of its `CHANGELOG.md`.
- A package that was never published by the Release workflow needs automated publishing on pub.dev.
  Go to pub.dev → the package → Admin → Automated publishing → GitHub Actions.
  Use repo `dartondox/dox`, tag pattern `v{{version}}` and environment `pub.dev`.
  Without it, the Release workflow fails on that package.
  A package in another repo uses that repo name, like `dartondox/dox-orm`.

In the steps below, replace `x.y.z` with the new version.

## 1. Bump the versions

```sh
git checkout -b release-x.y.z origin/main
```

1. Set `version: x.y.z` in the root `pubspec.yaml`.
2. Run `bash bin/update_versions.sh`.
   It sets the version of every package and every sibling constraint.
3. In every `packages/*/CHANGELOG.md`:
   - rename `## Unreleased` to `## x.y.z`, or
   - if there is no `## Unreleased`, add `## x.y.z` with "- Version bump only, to match the other packages."
4. Run `dart pub get` and `dart analyze --fatal-infos packages`.
5. Commit and push the branch.

## 2. Merge the release PR

Open a PR from `release-x.y.z` into `main`.
Wait for CI, then squash merge it.

## 3. Publish to pub.dev

Tag the merge commit on `main`:

```sh
git checkout main && git pull
git tag vx.y.z
git push origin vx.y.z
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

## 4. Release the project template

`dox create` copies a GitHub release of `dartondox/dox-sample` (branch `v3.x`).
It takes the newest release with the same major version as the CLI.

In `dox-sample`:

1. Set the `^x.y.z` versions in `pubspec.yaml` and `README.md`.
   Remove any `pubspec_overrides.yaml`.
2. Check it against pub.dev:
   ```sh
   dart pub get
   dart run build_runner build --delete-conflicting-outputs
   dart analyze
   ```
3. Commit and push `v3.x`.
4. Tag and release it:
   ```sh
   git tag vx.y.z && git push origin vx.y.z
   gh release create vx.y.z
   ```
5. Test it end to end:
   ```sh
   dox create demo && cd demo
   dart pub get   # dox create already made .env with a new APP_KEY
   dox s
   curl localhost:3000/ping   # pong
   ```

## 5. Check

- Every package shows the new version on pub.dev.
- The docs deploy from `main` passed (the "Docs" workflow).
- `dox create` makes a project with the new version.

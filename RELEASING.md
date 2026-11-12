# Releasing Dox

This guide shows how to release a new Dox version to pub.dev.
Each package in `packages/` has its own version and its own tag. Release only the packages that changed.

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
- `dox_auth`: [dartondox/dox-auth](https://github.com/dartondox/dox-auth)
- `dox_openapi`: [dartondox/dox-openapi](https://github.com/dartondox/dox-openapi)
- `dox_validation`: [dartondox/dox-validation](https://github.com/dartondox/dox-validation)
- `dox_socketio`: [dartondox/dox-socketio](https://github.com/dartondox/dox-socketio)
- `dox_storage`: [dartondox/dox-storage](https://github.com/dartondox/dox-storage)
- `dox_queue`: [dartondox/dox-queue](https://github.com/dartondox/dox-queue)
- `dox_scheduler`: [dartondox/dox-scheduler](https://github.com/dartondox/dox-scheduler)
- `dox` (the CLI, also called `dox_cli`): [dartondox/dox-cli](https://github.com/dartondox/dox-cli). Its version is also in `lib/src/version.dart`. Set both before you push the tag.

Each repo has its own version. To release, push a `v<version>` tag in that repo.
Its Release workflow publishes to pub.dev.

The dependencies go one way only, so release the repos in this order:

1. The native packages.
2. `dox-validation` and `dox-openapi`. They depend on no other Dox package.
3. This repo. `dox_core` depends on `dox_validation` and `dox_openapi`.
4. `dox-orm`. It depends on `dox_annotation` and `dox_validation`.
5. `dox-auth`, the CLI and the other package repos. They depend on `dox_core` or `dox_orm`.
6. The project template (`dox-sample`).

No package in this repo may depend on `dox_orm` or `dox_auth`. That would make a loop: neither repo could be released first.

## Before you start

- `main` has every change you want to ship, and CI is green.
- Each package with changes has a `## Unreleased` section at the top of its `CHANGELOG.md`.
- A package that was never published by the Release workflow needs automated publishing on pub.dev.
  Go to pub.dev → the package → Admin → Automated publishing → GitHub Actions.
  Use repo `dartondox/dox`, tag pattern `<package>-v{{version}}` (like `dox_core-v{{version}}`) and environment `pub.dev`.
  A new package in `packages/` needs this pattern before its first tag.
  Without it, the Release workflow fails on that package.
  A package in another repo uses that repo name, like `dartondox/dox-orm`.

In the steps below, replace `x.y.z` with the new version.

## 1. Bump the versions

```sh
git checkout -b release-x.y.z origin/main
```

Branch name: use the same name in every repo of a release, like `release-x.y.z`, so CI can clone the sibling repos on that branch (`ci/clone-siblings.sh`). A release that touches only the `dox` repo may use `release-<package>-x.y.z`.

Do this for each package that changed (`dox_annotation`, `dox_builder`, `dox_cache`, `dox_core`, `dox_cache_database`).

1. Run `bin/bump.sh <package> x.y.z`. It sets `version:` of that one package only.
2. If a package needs the new version of a sibling, raise that constraint by hand
   (for example `dox_annotation: ^x.y.z` in `dox_builder`).
3. In `packages/<package>/CHANGELOG.md`, rename `## Unreleased` to `## x.y.z`.
4. Run `dart pub get` and `dart analyze --fatal-infos packages`.
5. Commit and push the branch.

## 2. Merge the release PR

Open a PR from your release branch into `main`.
Wait for CI, then squash merge it.

## 3. Publish to pub.dev

Tag the merge commit on `main`. The tag is `<package>-vx.y.z`. One tag publishes one package.
If several packages changed, tag them one by one in dependency order:
`dox_annotation`, `dox_cache`, `dox_builder`, `dox_core`, `dox_cache_database` (the order of `bin/publish_order.py`).
Wait until the run of one tag is done (and the package is on pub.dev) before you push the next tag.

```sh
git checkout main && git pull
git tag dox_builder-vx.y.z
git push origin dox_builder-vx.y.z
```

The tag starts `.github/workflows/publish.yaml` (the "Release" workflow).
It checks that the tag matches the version in `packages/<folder>/pubspec.yaml`.
Then it runs the tests. Then it checks that every sibling it needs is on pub.dev (`ci/check-siblings.sh`; if not: "release <dep> first"). Then it checks the package with `dart pub publish --dry-run`
(in the workspace, so it needs no wait for pub.dev).
Then it uploads that one package, with `--skip-validation`.
If pub.dev refuses an upload, it tries again every 15 seconds, for up to 10 minutes.

A `dox_core-v*` tag also deploys the docs. The `docs-v*` tag deploys only the docs.

If the package fails (for example, automated publishing is off):

1. Fix the cause.
2. Run `gh run rerun <run id> --failed`.

If the version is already on pub.dev, it is skipped.

To test without publishing, run the Release workflow by hand (workflow_dispatch).
Pick one package, or `all`. That is a dry run only.

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

# Contributing to Dox

Thank you for helping Dox. The full guide is here:
https://dartondox.dev/latest/community/contribute/
(source: `docs/community/contribute.md`)

## Bugs and feature requests

Use GitHub issues: https://github.com/dartondox/dox/issues

For security problems, see [SECURITY.md](SECURITY.md). Do not open a public issue.

## Pull requests

Send changes as pull requests against `main`. Before you ask for review:

- CI is green.
- `melos run analyze` (`dart analyze --fatal-infos`) has no warnings.
- `melos run format_check` passes.
- Add a changelog entry under `## Unreleased` in the package `CHANGELOG.md`.
- Do not change versions in the PR.

## Tests

Every new feature and every bug fix must add tests.

Run the tests with `melos run test`. CI runs them on every push and pull request.

## Fuzz tests

A fuzz target gives many changed inputs to a parser of client input. It fails when the parser throws an error that is not a 4xx answer, when the result is wrong, or when the parser does not end. The targets are in `packages/dox-core/fuzz`. One file is one target. They use the [covfuzz](https://pub.dev/packages/covfuzz) package.

Run one target from `packages/dox-core`:

```sh
dart run --enable-vm-service=0 --no-pause-isolates-on-exit fuzz/form_body.dart
```

The run prints its random seed. To run the same inputs again, give the seed as the first argument. The second argument is the time of the coverage part in seconds (default 60).

CI runs all targets when `packages/dox-core` changes (`.github/workflows/fuzz.yml`). When a target fails, the log shows the smallest input that fails. Add that input to the unit tests with the fix.

To add a target, add a file with a class that extends one of these:

- `FuzzTarget`, for a parser that is synchronous. It uses covfuzz, with coverage feedback.
- `AsyncFuzzTarget`, for a parser that reads a stream (see `fuzz/multipart.dart`). covfuzz can only call synchronous code, so this class has its own loop with no coverage feedback.

In `check`, call the parser with the same steps as the server. Then throw an error if the result breaks a rule that must always be true.

## Code style

Follow the lints in each package's `analysis_options.yaml`.

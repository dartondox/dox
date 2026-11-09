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

## Code style

Follow the lints in each package's `analysis_options.yaml`.

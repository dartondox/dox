#!/usr/bin/env bash
# Finds out if a push changes code, or only docs. Writes code=true or
# code=false to $GITHUB_OUTPUT. Docs only means *.md, docs/, mkdocs.yml and
# overrides/. A branch is compared with develop, so one docs-only push on
# top of code commits still runs every test.
#
# Env: BEFORE (github.event.before), GITHUB_REF_TYPE, GITHUB_REF and
# GITHUB_OUTPUT (set by GitHub Actions). Needs the full git history.
set -euo pipefail

if [ "$GITHUB_REF_TYPE" = "tag" ]; then
  echo "code=true" >> "$GITHUB_OUTPUT"; exit 0
fi
if [ "$GITHUB_REF" = "refs/heads/develop" ]; then
  base="$BEFORE"
else
  base=$(git merge-base origin/develop HEAD)
fi
# no usable base (new branch, force push): run everything
if ! git cat-file -e "$base^{commit}" 2>/dev/null; then
  echo "code=true" >> "$GITHUB_OUTPUT"; exit 0
fi
files=$(git diff --name-only "$base" HEAD)
echo "$files"
if grep -qvE '(\.md$|^docs/|^mkdocs\.yml$|^overrides/|^$)' <<< "$files"; then
  echo "code=true" >> "$GITHUB_OUTPUT"
else
  echo "Only docs changed. Tests are skipped."
  echo "code=false" >> "$GITHUB_OUTPUT"
fi

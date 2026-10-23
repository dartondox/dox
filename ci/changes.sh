#!/usr/bin/env bash
# Finds the files a push changes, then lets ci/affected.py pick the jobs to
# run. Writes code, changed, tests and examples to $GITHUB_OUTPUT (see
# ci/affected.py). A branch is compared with develop, so one docs-only push
# on top of code commits still runs the tests of that code. Tags, and
# pushes with no usable base (new branch, force push), run everything.
#
# Env: BEFORE (github.event.before), GITHUB_REF_TYPE, GITHUB_REF and
# GITHUB_OUTPUT (set by GitHub Actions). Needs the full git history.
set -euo pipefail
cd "$(dirname "$0")/.."

all=0
files=""
if [ "$GITHUB_REF_TYPE" = "tag" ]; then
  all=1
else
  if [ "$GITHUB_REF" = "refs/heads/develop" ]; then
    base="$BEFORE"
  else
    base=$(git merge-base origin/develop HEAD || true)
  fi
  if git cat-file -e "$base^{commit}" 2>/dev/null; then
    files=$(git diff --name-only "$base" HEAD)
  else
    all=1
  fi
fi

echo "$files"
out=$(ALL=$all python3 ci/affected.py <<< "$files")
echo "$out"
echo "$out" >> "$GITHUB_OUTPUT"

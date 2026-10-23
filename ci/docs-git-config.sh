#!/usr/bin/env bash
# Sets the git user for the docs deploy commits, and fetches the gh-pages
# branch when it is there.
set -euo pipefail

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git fetch origin gh-pages:gh-pages || true

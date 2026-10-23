#!/usr/bin/env bash
# Uploads the built libraries in dist/ to the GitHub release of the tag,
# with a SHA256SUMS file. Creates the release when it is not there yet.
#
# Args: the library name, like dox_http_native.
# Env: TAG (the tag name), GH_TOKEN, GITHUB_REPOSITORY.
set -euo pipefail

name=$1
cd dist
sha256sum "$name"-* > SHA256SUMS
cat SHA256SUMS
if gh release view "$TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$TAG" ./* --clobber --repo "$GITHUB_REPOSITORY"
else
  # never "latest": that stays the framework release.
  # a version with "-" (like 3.0.0-alpha.2) is a prerelease.
  pre=()
  case "$TAG" in *-v*-*) pre=(--prerelease) ;; esac
  gh release create "$TAG" ./* --repo "$GITHUB_REPOSITORY" ${pre[@]+"${pre[@]}"} --latest=false \
    --title "$TAG" --notes "Ready-built $name libraries. See SHA256SUMS."
fi

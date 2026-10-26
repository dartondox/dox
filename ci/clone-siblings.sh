#!/usr/bin/env bash
# Clones the Dox repos that live outside this one next to it:
# ../dox-orm, ../dox-socketio, ../dox-storage, ../dox-queue,
# ../dox-scheduler and ../dox-cli. The examples (their
# pubspec_overrides.yaml) and ci/smoke-template.sh use these clones, so
# they run on the newest code of those packages.
# A repo with a branch of the same name as this one (eg. a PR that
# changes both repos) is cloned on that branch, else on main.
# A folder that is already there is kept (local dev).
set -euo pipefail
parent=$(cd "$(dirname "$0")/../.." && pwd)
branch=${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}

for repo in dox-orm dox-socketio dox-storage dox-queue dox-scheduler dox-cli; do
  if [ -d "$parent/$repo" ]; then
    echo "$parent/$repo is there"
    continue
  fi
  url="https://github.com/dartondox/$repo.git"
  if [ -n "$branch" ] && git ls-remote --exit-code --heads "$url" "$branch" >/dev/null; then
    echo "$repo: branch $branch"
    git clone --depth 1 --branch "$branch" "$url" "$parent/$repo"
  else
    git clone --depth 1 "$url" "$parent/$repo"
  fi
done

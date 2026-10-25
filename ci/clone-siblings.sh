#!/usr/bin/env bash
# Clones the Dox repos that live outside this one next to it:
# ../dox-orm, ../dox-socketio and ../dox-storage (branch main).
# The examples (their pubspec_overrides.yaml) and ci/smoke-template.sh
# use these clones, so they run on the newest code of those packages.
# A folder that is already there is kept (local dev).
set -euo pipefail
parent=$(cd "$(dirname "$0")/../.." && pwd)

for repo in dox-orm dox-socketio dox-storage; do
  if [ -d "$parent/$repo" ]; then
    echo "$parent/$repo is there"
    continue
  fi
  git clone --depth 1 "https://github.com/dartondox/$repo.git" "$parent/$repo"
done

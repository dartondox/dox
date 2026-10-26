#!/usr/bin/env bash
# Smoke test of a new app made from the released template, on the Dox
# packages of this commit. It catches a change that breaks apps, the
# template, dox_queue or dox_scheduler before it is merged.
#
# Steps: `dox create` (the CLI from ../dox-cli), override all Dox packages
# with this repo (and with ../dox-orm, ../dox-auth, ../dox-openapi,
# ../dox-validation, ../dox-socketio, ../dox-storage, ../dox-queue,
# ../dox-scheduler when they are there, see
# ci/clone-siblings.sh),
# build_runner, analyze, the template tests, migrate, `dox build`, then
# start the AOT server and call its routes.
#
# Env: TEMPLATE_VERSION (optional) is passed to `dox create --version`.
# Without it, `dox create` picks the newest template of this major.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)

# The CLI lives in its own repo. ci/clone-siblings.sh clones it.
[ -f "$root/../dox-cli/pubspec.yaml" ] || { echo "::error::no ../dox-cli, run ci/clone-siblings.sh"; exit 1; }
dart pub global activate --source path "$root/../dox-cli" >/dev/null
export PATH="$PATH:$HOME/.pub-cache/bin"

work=$(mktemp -d)
cd "$work"
dox create smoke_app ${TEMPLATE_VERSION:+--version "$TEMPLATE_VERSION"}
# `dox create` prints its errors, so check the result here
[ -f smoke_app/pubspec.yaml ] || { echo "::error::dox create made no app"; exit 1; }
cd smoke_app
# a port that a dev server on 3000 does not hold
port=39123
sed -i.bak "s/^APP_PORT=.*/APP_PORT=$port/" .env && rm .env.bak

{
  echo "# the Dox packages of this commit, not the ones on pub.dev"
  echo "dependency_overrides:"
  for dir in "$root"/packages/*/ "$root"/../dox-orm/packages/*/ \
    "$root"/../dox-auth/ "$root"/../dox-openapi/ "$root"/../dox-validation/ \
    "$root"/../dox-socketio/ "$root"/../dox-storage/ \
    "$root"/../dox-queue/ "$root"/../dox-scheduler/; do
    [ -f "$dir/pubspec.yaml" ] || continue
    name=$(sed -nE 's/^name:[[:space:]]*([a-z0-9_]+).*/\1/p' "$dir/pubspec.yaml")
    printf '  %s:\n    path: %s\n' "$name" "${dir%/}"
  done
} > pubspec_overrides.yaml

dart pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart test --concurrency=1
dox migrate
dox build

# the AOT server, run like in production
cp .env build/bundle/.env
cd build/bundle
./bin/server > "$work/server.log" 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT

ok=""
for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:$port/ping" >/dev/null 2>&1; then ok=1; break; fi
  sleep 1
done
if [ -z "$ok" ]; then
  echo "::error::the server did not answer /ping"
  cat "$work/server.log"
  exit 1
fi

for path in /ping /api/ping; do
  echo "GET $path -> $(curl -fsS "http://127.0.0.1:$port$path")"
done
# an unknown route must be a 404, not a crash
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/no-such-route")
[ "$code" = 404 ] || { echo "::error::/no-such-route gave $code, want 404"; exit 1; }
echo "smoke test passed"

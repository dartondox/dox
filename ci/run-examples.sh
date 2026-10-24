#!/usr/bin/env bash
# Builds, analyzes and tests the apps in examples/, one after the other.
# Each example has its own .env, .dart_tool and pubspec.lock. A failed
# example does not stop the next one. Exit code 1 when any failed.
#
# Args: the folders under examples/ to run.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

failed=""
for e in "$@"; do
  echo "::group::example $e"
  # One test file at a time: the test files of blog-api share one SQLite file.
  # .env.example has an empty APP_KEY, so each run makes its own key.
  if ! (cd "examples/$e" &&
    key=$(openssl rand -hex 16) &&
    sed "s/^APP_KEY=.*/APP_KEY=$key/" .env.example > .env &&
    dart pub get &&
    dart run build_runner build --delete-conflicting-outputs &&
    dart analyze --fatal-infos &&
    dart test --concurrency=1); then
    failed="$failed $e"
  fi
  echo "::endgroup::"
done

if [ -n "$failed" ]; then
  echo "::error::these examples failed:$failed"
  exit 1
fi

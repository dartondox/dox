#!/usr/bin/env bash
# CI only. Makes the sqlite3 build hook use the SQLite library of the
# runner (libsqlite3.so), so it does not download one from GitHub
# releases. GitHub downloads fail now and then (503/504), and the hook
# does not check the HTTP status.
#
# It adds the `hooks` block to each pubspec.yaml given as an argument
# (the root pubspec of a workspace or an app). Never commit that block to
# a package that is published to pub.dev: users would get it too.
# Run it before `dart pub get`.
set -euo pipefail

# libsqlite3.so (no version in the name) comes from the -dev package.
# grep reads all lines (no -q): with -q it can stop early, ldconfig then
# gets SIGPIPE, and pipefail makes the check fail.
if [ "$(uname)" = Linux ] && ! ldconfig -p | grep 'libsqlite3\.so ' >/dev/null; then
  sudo apt-get install -y libsqlite3-dev
fi

# A pubspec that has a hooks block already (like the app template, which
# skips the Postgres and MySQL drivers) gets the sqlite3 lines inside it.
for file in "$@"; do
  if grep -q '^    sqlite3:' "$file"; then
    echo "$file: sets sqlite3 already, not changed"
    continue
  fi
  if grep -q '^  user_defines:' "$file"; then
    awk '{ print } /^  user_defines:/ { print "    sqlite3:"; print "      source: system" }' \
      "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  elif grep -q '^hooks:' "$file"; then
    awk '{ print } /^hooks:/ { print "  user_defines:"; print "    sqlite3:"; print "      source: system" }' \
      "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    printf '\nhooks:\n  user_defines:\n    sqlite3:\n      source: system\n' >> "$file"
  fi
  echo "$file: sqlite3 uses the system library"
done

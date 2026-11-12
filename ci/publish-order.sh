#!/usr/bin/env bash
# Prints the packages to release, as folder:package, one per line.
# Also saves them as PACKAGES (space separated) in $GITHUB_ENV, so the next
# steps of the job can use them. Outside of GitHub Actions it only prints.
#
# - On a tag like dox_builder-v3.1.4: only that package. An unknown package
#   or a bad version stops with an error.
# - Else, PACKAGE (optional) is one package name: only that package.
#   Empty or `all` means all packages.
# - Else: all packages, in publish order.
#
# bin/publish_order.py sorts the packages by their pubspecs: each one comes
# after every sibling it depends on (dev_dependencies too, pub checks them
# on publish).
#
# Env (set by GitHub Actions): GITHUB_REF_TYPE, GITHUB_REF_NAME.
set -euo pipefail

ALL=$(python3 bin/publish_order.py)
name=${PACKAGE:-}
[ "$name" = all ] && name=""

if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  tag=$GITHUB_REF_NAME
  case $tag in
    *-v*) ;;
    *) echo "::error::Tag $tag is not like <package>-v<version>"; exit 1 ;;
  esac
  name=${tag%%-v*}
  version=${tag#*-v}
  if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    echo "::error::Tag $tag has a bad version '$version'. Use <package>-vX.Y.Z"
    exit 1
  fi
fi

if [ -n "$name" ]; then
  LIST=$(echo "$ALL" | awk -F: -v n="$name" '$2 == n')
  if [ -z "$LIST" ]; then
    echo "::error::Unknown package '$name'. Known: $(echo "$ALL" | cut -d: -f2 | tr '\n' ' ')"
    exit 1
  fi
else
  LIST=$ALL
fi

PACKAGES=$(echo "$LIST" | tr '\n' ' ')
echo "$LIST"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "PACKAGES=$PACKAGES" >> "$GITHUB_ENV"
fi

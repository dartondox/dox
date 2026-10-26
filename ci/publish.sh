#!/usr/bin/env bash
# Publishes every package to pub.dev, in publish order. A package that is
# already on pub.dev with this version is skipped, so a failed release can
# be run again.
#
# Env: PACKAGES (from ci/publish-order.sh), GITHUB_REF_NAME (the tag, like
# v<version>), ACTIONS_ID_TOKEN_REQUEST_TOKEN and
# ACTIONS_ID_TOKEN_REQUEST_URL (set by GitHub Actions with id-token: write).
# Needs dart, curl and jq.
set -euo pipefail

VERSION=${GITHUB_REF_NAME#v}

has_version() {
  curl -sf "https://pub.dev/api/packages/$1" \
    | jq -e --arg v "$VERSION" 'any(.versions[]; .version == $v)' > /dev/null
}

# The pub client can see an older, cached package list than the API
# does (CDN lag). So wait until `dart pub get` itself resolves the new
# version. Then the next package's publish can resolve it too.
# A fresh PUB_CACHE per probe, so no local cached list hides the new version.
# Args: package, number of tries, seconds between tries.
wait_resolvable() {
  probe=$(mktemp -d)
  printf 'name: probe\nenvironment:\n  sdk: ^3.0.0\ndependencies:\n  %s: %s\n' \
    "$1" "$VERSION" > "$probe/pubspec.yaml"
  for i in $(seq 1 "$2"); do
    if (cd "$probe" && PUB_CACHE="$probe/cache" dart pub get > "$probe/log" 2>&1); then
      echo "$1 $VERSION resolves with dart pub get."
      rm -rf "$probe"
      return 0
    fi
    # a sibling it needs comes later in the publish order: waiting will
    # not help. A sibling that comes earlier was published already, and
    # pub.dev may just not show it yet (CDN lag), so keep waiting then.
    later=0
    for other in $PACKAGES; do
      sib=${other##*:}
      if [ "$sib" = "$1" ]; then later=1; continue; fi
      if [ "$later" = 1 ] && grep -qw "$sib" "$probe/log" \
        && grep -q "doesn't match any versions" "$probe/log" \
        && ! has_version "$sib"; then
        cat "$probe/log"
        echo "::error::$1 $VERSION needs $sib $VERSION, which is not on pub.dev. Fix the publish order (bin/publish_order.py)."
        exit 1
      fi
    done
    echo "Waiting for dart pub get to resolve $1 $VERSION ($i/$2)"
    sleep "$3"
  done
  cat "$probe/log"
  echo "::error::dart pub get still cannot resolve $1 $VERSION"
  exit 1
}

# The OIDC token from setup-dart lives only a few minutes. The waits
# above can take longer, so get a new token right before each publish.
# Same steps as setup-dart: OIDC token for audience https://pub.dev,
# put it in PUB_TOKEN, register it with `dart pub token add`.
refresh_pub_token() {
  # `|| true`: on a curl error, show the error below instead of stopping here.
  PUB_TOKEN=$(curl -sSf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
    "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=https://pub.dev" | jq -r '.value') || true
  if [ -z "$PUB_TOKEN" ] || [ "$PUB_TOKEN" = "null" ]; then
    echo "::error::Could not get a new OIDC token for pub.dev"
    exit 1
  fi
  echo "::add-mask::$PUB_TOKEN"
  export PUB_TOKEN
  dart pub token add https://pub.dev --env-var PUB_TOKEN
}

# Wait only where it is needed: right before a package is published,
# wait until each Dox package it depends on (dev_dependencies too)
# resolves with `dart pub get`. Packages with no Dox dependency go
# out back to back. A dependency that resolved once is not checked
# again.
resolved=" "
for entry in $PACKAGES; do
  dir=${entry%%:*}
  name=${entry##*:}
  if has_version "$name"; then
    echo "$name $VERSION is already on pub.dev. Skipping."
    continue
  fi
  for other in $PACKAGES; do
    dep=${other##*:}
    if [ "$dep" != "$name" ] && grep -qE "^[[:space:]]+$dep:" "packages/$dir/pubspec.yaml" \
      && [ "${resolved#* "$dep" }" = "$resolved" ]; then
      wait_resolvable "$dep" 40 15
      resolved="$resolved$dep "
    fi
  done
  echo "::group::Publish $name $VERSION"
  refresh_pub_token
  # the API above can lag too: "already exists" means it is published
  log=$(mktemp)
  if ! (cd "packages/$dir" && dart pub publish --force) 2>&1 | tee "$log"; then
    grep -q "already exists" "$log" || exit 1
    echo "$name $VERSION was already published."
  fi
  echo "::endgroup::"
done

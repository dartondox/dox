#!/usr/bin/env bash
# Publishes every package to pub.dev, in publish order. A package that is
# already on pub.dev with this version is skipped, so a failed release can
# be run again.
#
# The packages are checked before this script, with `dart pub publish
# --dry-run` in the workspace (ci/publish-dry-run.sh). So the uploads here
# use `--skip-validation`: pub does not resolve the dependencies again, and
# does not wait until pub.dev serves the sibling that was uploaded just
# before. That wait (CDN lag) took minutes per package.
#
# If pub.dev still refuses an upload, it is tried again every 15 seconds,
# at most 40 times (10 minutes).
#
# Env: PACKAGES (from ci/publish-order.sh), GITHUB_REF_NAME (the tag, like
# v<version>), ACTIONS_ID_TOKEN_REQUEST_TOKEN and
# ACTIONS_ID_TOKEN_REQUEST_URL (set by GitHub Actions with id-token: write).
# Needs dart, curl and jq.
set -euo pipefail

VERSION=${GITHUB_REF_NAME#v}
TRIES=40
WAIT=15

has_version() {
  curl -sf "https://pub.dev/api/packages/$1" \
    | jq -e --arg v "$VERSION" 'any(.versions[]; .version == $v)' > /dev/null
}

# The OIDC token from setup-dart lives only a few minutes. Retries can take
# longer, so get a new token right before each upload.
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

for entry in $PACKAGES; do
  dir=${entry%%:*}
  name=${entry##*:}
  if has_version "$name"; then
    echo "$name $VERSION is already on pub.dev. Skipping."
    continue
  fi
  echo "::group::Publish $name $VERSION"
  log=$(mktemp)
  for i in $(seq 1 "$TRIES"); do
    refresh_pub_token
    if (cd "packages/$dir" && dart pub publish --force --skip-validation) 2>&1 | tee "$log"; then
      break
    fi
    # the API above can lag too: "already exists" means it is published
    if grep -q "already exists" "$log"; then
      echo "$name $VERSION was already published."
      break
    fi
    if [ "$i" = "$TRIES" ]; then
      echo "::error::pub.dev refused $name $VERSION $TRIES times"
      exit 1
    fi
    echo "pub.dev refused $name $VERSION ($i/$TRIES). Trying again in $WAIT seconds."
    sleep "$WAIT"
  done
  echo "::endgroup::"
done

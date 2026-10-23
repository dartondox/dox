#!/usr/bin/env bash
# Waits up to 90 seconds for each service from ci/start-services.sh to be up.
# MinIO is checked by its health URL, the others by their docker health check.
#
# Args: the services to wait for (same names as ci/start-services.sh).
set -euo pipefail

for s in "$@"; do
  if [ "$s" = minio ]; then
    timeout 90 sh -c 'until curl -sf http://localhost:9100/minio/health/live; do sleep 1; done'
  else
    # shellcheck disable=SC2016 # $1 is expanded by the inner sh
    timeout 90 sh -c 'until [ "$(docker inspect -f "{{.State.Health.Status}}" "$1")" = healthy ]; do sleep 1; done' sh "$s"
  fi
  echo "$s is up"
done

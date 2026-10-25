#!/usr/bin/env bash
# Starts test services as docker containers, in the background.
# They boot while the next steps run. Use ci/wait-services.sh to wait.
#
# Args: the services to start: redis.
# The database tests live in dartondox/dox-orm now.
set -euo pipefail

for s in "$@"; do
  case $s in
    redis)
      docker run -d --name redis -p 6379:6379 \
        --health-cmd "redis-cli ping" --health-interval 2s redis:7 ;;
  esac
done

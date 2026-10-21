#!/usr/bin/env bash
# Benchmark Dox: JIT vs AOT, 1 vs N isolates, JSON route and 50 MB upload.
# Usage: bash benchmark/run.sh   (from packages/dox-core)
set -euo pipefail
cd "$(dirname "$0")/.."
N=${N:-$(sysctl -n hw.ncpu 2>/dev/null || nproc)}
SECS=${SECS:-10}
CONNS=${CONNS:-64}
PORT=4000
mkdir -p build
dart compile exe benchmark/server.dart -o build/bench_server >/dev/null
dart compile exe benchmark/load.dart -o build/bench_load >/dev/null
dart compile exe benchmark/upload.dart -o build/bench_upload >/dev/null

run() { # $1 label, rest = server command
  local label=$1; shift
  local t0; t0=$(perl -MTime::HiRes=time -e 'print time')
  "$@" >/dev/null 2>&1 &
  local pid=$!
  until curl -s "http://127.0.0.1:$PORT/json" >/dev/null; do sleep 0.02; done
  local t1; t1=$(perl -MTime::HiRes=time -e 'print time')
  sleep 1
  echo "== $label"
  echo "  startup: $(perl -e "printf '%.2f', $t1-$t0")s  idle $(curl -s "http://127.0.0.1:$PORT/rss")"
  echo -n "  json:    "; build/bench_load "http://127.0.0.1:$PORT/json" "$CONNS" "$SECS" 4
  echo -n "  param:   "; build/bench_load "http://127.0.0.1:$PORT/user/42" "$CONNS" "$SECS" 4
  kill $pid; wait $pid 2>/dev/null || true
  # fresh process so peak RSS only shows the upload
  "$@" >/dev/null 2>&1 &
  pid=$!
  until curl -s "http://127.0.0.1:$PORT/json" >/dev/null; do sleep 0.2; done
  echo -n "  upload:  "; build/bench_upload "http://127.0.0.1:$PORT" 50 /upload | tr '\n' ' '; echo
  kill $pid; wait $pid 2>/dev/null || true
  "$@" >/dev/null 2>&1 &
  pid=$!
  until curl -s "http://127.0.0.1:$PORT/json" >/dev/null; do sleep 0.2; done
  echo -n "  upload+bytes: "; build/bench_upload "http://127.0.0.1:$PORT" 50 /upload/bytes | tr '\n' ' '; echo
  kill $pid; wait $pid 2>/dev/null || true
}

run "JIT 1 isolate"  dart run benchmark/server.dart 1 $PORT
run "AOT 1 isolate"  build/bench_server 1 $PORT
run "JIT $N isolates" dart run benchmark/server.dart "$N" $PORT
run "AOT $N isolates" build/bench_server "$N" $PORT

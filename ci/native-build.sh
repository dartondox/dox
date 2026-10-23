#!/usr/bin/env bash
# Builds the Rust library of a native package for one target, and copies
# it to dist/<asset> at the repo root.
#
# Args: the package folder under packages/ (like dox-http-native).
# Env: TARGET (Rust target), FILE (the built file name), ASSET (the file
# name in dist/ and in the GitHub release).
set -euo pipefail

cd "packages/$1/native"
cargo build --release --target "$TARGET"
mkdir -p ../../../dist
cp "target/$TARGET/release/$FILE" "../../../dist/$ASSET"

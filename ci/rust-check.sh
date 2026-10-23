#!/usr/bin/env bash
# Rust checks of a native package: format, clippy, tests, release build.
# The release build is kept: the Dart build hook uses native/target/release
# when it is there.
#
# Args: the package folder under packages/ (like dox-http-native), then
# extra args for `cargo test` (like --release).
set -euo pipefail

cd "packages/$1/native"
shift
cargo fmt --check
cargo clippy --release --all-targets -- -D warnings
cargo test "$@"
cargo build --release

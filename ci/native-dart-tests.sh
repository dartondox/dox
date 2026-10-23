#!/usr/bin/env bash
# Dart tests of a native package: pub get, analyze, then dart test.
# Run ci/rust-check.sh first: the build hook uses native/target/release
# when it is there.
#
# Args: the package folder under packages/ (like dox-http-native).
# dox-postgres-native needs Postgres on 5432. dox-mysql-native needs
# MariaDB on 3306 and MySQL 8.4 on 3307 (see ci/start-services.sh).
set -euo pipefail

cd "packages/$1"
dart pub get
dart analyze --fatal-infos .
case $1 in
  dox-postgres-native)
    DRIVER=postgres DB_PORT=5432 dart test --concurrency=1 ;;
  dox-mysql-native)
    echo "::group::MariaDB 11"
    DB_PORT=3306 DB_USER=dox dart test --concurrency=1
    echo "::endgroup::"
    echo "::group::MySQL 8.4"
    DB_PORT=3307 DB_USER=dox dart test --concurrency=1
    echo "::endgroup::" ;;
  *)
    dart test --concurrency=1 ;;
esac

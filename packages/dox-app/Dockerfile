# Production image: an AOT-compiled binary on an empty (scratch) base.
# Never run production with `dart run`. It uses the JIT: more memory,
# slower start. See docs/digging-deeper/deployment.md.
#
# This app is a package of the dox pub workspace, so build it from the
# repo root (docker-compose.yml does this):
#   docker build -f packages/dox-app/Dockerfile .

FROM dart:stable AS build

# Resolve the workspace (one pubspec.lock at the root).
WORKDIR /src
COPY . .
RUN dart pub get

# `dart build cli` is AOT like `dart compile exe`, and it also runs build
# hooks. sqlite3 v3 uses a build hook to bundle SQLite into build/bundle/lib.
WORKDIR /src/packages/dox-app
RUN dart run build_runner build
RUN dart build cli --target bin/server.dart --output build

# Lay out the final file tree:
# /app/bin/server, /app/lib (native libraries), /app/db/migration,
# /app/storage and a writable /tmp (uploads bigger than 1 MB are streamed
# to a temp file).
RUN mkdir -p /out/app/storage /out/tmp \
  && chmod 1777 /out/tmp \
  && cp -r build/bundle/. /out/app/ \
  && cp -r db /out/app/db

# Minimal serving image: the AOT runtime files from the dart image
# (`/runtime/`) plus our bundle. No Dart SDK, no source code.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/ /
WORKDIR /app

# Config comes from environment variables, eg.
# docker run -e APP_KEY=... -e DB_HOST=... -p 3000:3000 image
# (a .env file is not copied into the image, so secrets stay out of it)
EXPOSE 3000
CMD ["/app/bin/server"]

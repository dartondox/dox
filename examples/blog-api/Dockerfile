FROM dart:stable AS build

# Resolve dependencies first, so this layer is cached.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart run build_runner build --delete-conflicting-outputs

# `dart build cli` is AOT like `dart compile exe`, and it also runs
# build hooks. Native libraries go to build/bundle/lib.
RUN dart build cli --target bin/server.dart --output build

# Lay out the final file tree:
# /app/bin/server, /app/lib (native libraries), /app/db/migration,
# /app/storage and a writable /tmp (uploads bigger than 1 MB are
# streamed to a temp file).
RUN mkdir -p /out/app/storage /out/tmp \
  && chmod 1777 /out/tmp \
  && cp -r build/bundle/. /out/app/ \
  && cp -r db /out/app/db \
  # the native HTTP server (Rust) needs libgcc_s, which /runtime/ does not have
  && LIBGCC=$(find / -name libgcc_s.so.1 -path '*lib*' | head -n 1) \
  && mkdir -p /out$(dirname $LIBGCC) && cp $LIBGCC /out$LIBGCC

# Minimal serving image: the AOT runtime files from the dart image
# (`/runtime/`) plus our bundle. No Dart SDK, no source code.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/ /
WORKDIR /app

# Config comes from env variables. The image has no .env file,
# so secrets stay out of it.
EXPOSE 3000
CMD ["/app/bin/server"]

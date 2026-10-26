# Stage 1: build the AOT bundle with the Dart SDK and the dox CLI.
FROM dart:stable AS build

WORKDIR /app

# Resolve dependencies first, so Docker caches this layer.
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline

# `dox build` runs build_runner, then `dart build cli`.
# The bundle is in build/bundle: bin/server, lib/, db/, .env.example
# (and bin/queue, bin/schedule when the app has them)
RUN dart pub global activate dox ^3.0.0-alpha \
  && /root/.pub-cache/bin/dox build

# The health check binary. Plain dart:io, so `dart compile exe` is fine.
RUN dart compile exe bin/health.dart -o build/bundle/bin/health

# Lay out the final file tree. /tmp must be writable: uploads bigger
# than 1 MB are streamed to a temp file.
RUN mkdir -p /out/app/storage /out/app/public /out/tmp \
  && chmod 1777 /out/tmp \
  && cp -r build/bundle/. /out/app/ \
  && cp -r public/. /out/app/public/ \
  # the native HTTP server (Rust) needs libgcc_s, which /runtime/ does not have
  && LIBGCC=$(find / -name libgcc_s.so.1 -path '*lib*' | head -n 1) \
  && mkdir -p /out$(dirname $LIBGCC) && cp $LIBGCC /out$LIBGCC

# Stage 2: the Dart AOT runtime and the bundle only. No SDK, no source.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/ /
WORKDIR /app

# Config comes from env variables. The image has no .env file.
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD ["/app/bin/health"]
CMD ["/app/bin/server"]

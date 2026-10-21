# Production image: an AOT-compiled binary on an empty (scratch) base.
# Never run production with `dart run`. It uses the JIT: more memory,
# slower start. See docs/digging-deeper/deployment.md.

FROM dart:stable AS build

# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code (except anything in .dockerignore) and AOT compile app.
COPY . .
RUN dart pub get --offline
RUN dart run build_runner build --delete-conflicting-outputs
RUN mkdir -p build && dart compile exe bin/server.dart -o build/server

# Lay out the final file tree:
# /app/bin/server, /app/db/migration, /app/storage and a writable /tmp
# (uploads bigger than 1 MB are streamed to a temp file).
RUN mkdir -p /out/app/bin /out/app/storage /out/tmp \
  && chmod 1777 /out/tmp \
  && cp build/server /out/app/bin/server \
  && cp -r db /out/app/db

# Minimal serving image: the AOT runtime files from the dart image
# (`/runtime/`) plus our binary. No Dart SDK, no source code.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/ /
WORKDIR /app

# Config comes from environment variables, eg.
# docker run -e APP_KEY=... -e DB_HOST=... -p 3000:3000 image
# (a .env file is not copied into the image, so secrets stay out of it)
EXPOSE 3000
CMD ["/app/bin/server"]

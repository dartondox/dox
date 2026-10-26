# Guides example

This app holds the code of the [guides](../../docs/guides/index.md) that use `dox create my_app`, in one project.
The OpenAPI and deploy guides use [examples/blog-api](../blog-api) instead.
Dox is a new web framework for Dart. Each guide adds a few files to this app.

| Guide | Files |
| --- | --- |
| [File upload](../../docs/guides/file-upload.md) | `upload.controller.dart`, `upload_image/upload_image.dto.dart`, `config/storage.dart` |
| [Pagination](../../docs/guides/pagination.md) | `user.controller.dart`, `list_users/list_users.dto.dart` |
| [JWT authentication](../../docs/guides/jwt-auth.md) | `auth.controller.dart`, `providers/auth_provider.dart`, the DTOs |
| [Custom errors](../../docs/guides/custom-errors.md) | `exceptions/app_exception.dart`, `response_handler.dart`, `error_handler.dart` |
| [Background work](../../docs/guides/background-work.md) | `report.controller.dart`, `jobs/build_report.job.dart`, `config/queue.dart`, `config/schedule.dart`, `bin/queue.dart`, `bin/schedule.dart` |
| [Docker](../../docs/guides/docker.md) | `Route.health` in `routes/web.dart`, `bin/health.dart`, `Dockerfile`, `docker-compose.yml` |
| [Testing with a database](../../docs/guides/testing-with-database.md) | `test/user_test.dart`, the migration |
| [Static files and SPA](../../docs/guides/static-files.md) | `static.controller.dart`, `routes/web.dart`, `public/` |
| [CORS for a browser front-end](../../docs/guides/cors-for-spa.md) | `config/cors.dart` |
| [Environments](../../docs/guides/environments.md) | `config/env.dart`, `config/logger.dart`, `config/database.dart` |

The package name is `my_app`, like in the guides.
The app uses the Dox packages of this repo, not the ones on pub.dev.
`pubspec_overrides.yaml` points to them.

## Run the tests

The app uses SQLite. You need no database server and no Docker.

```bash
cp .env.example .env
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart test --concurrency=1
```

- `test/user_test.dart` is the test of the "Testing with a database" guide.
- `test/http_test.dart` starts the app on `APP_PORT` (3000) and runs the "Check it" steps of the guides.

CI runs these steps on every push, so the code of the guides keeps working.

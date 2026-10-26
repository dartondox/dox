# Guides

Each guide solves one job from start to end: copy the files, run the commands, and check the result.

The reference pages explain each part in more detail. The guides link to them.

| Guide | What you get |
| --- | --- |
| [File upload](file-upload.md) | Accept an image, check its size and type, save it, return its URL. |
| [Pagination](pagination.md) | A list route with `page` and `per_page`, and the JSON shape it returns. |
| [JWT authentication](jwt-auth.md) | Register, log in, protect routes, read the user, log out. |
| [Custom errors](custom-errors.md) | Your own exception classes, one JSON shape for every error, logging. |
| [Background work](background-work.md) | Run work after the response, on another thread, in a queue job, or on a schedule. |
| [Static files and SPA](static-files.md) | Serve a folder or a single page app, with cache headers. |
| [CORS for a browser front-end](cors-for-spa.md) | The CORS setup that works with a React, Vue or Flutter web app. |
| [Environments](environments.md) | Dev, staging and production config, `.env` files, secrets and `APP_KEY`. |
| [Testing with a database](testing-with-database.md) | Tests on SQLite or a test Postgres, with migrations and cleanup. |
| [Share code with Flutter](share-code-with-flutter.md) | One DTO package that the server and the Flutter app both use to check input. |
| [API docs with OpenAPI](api-docs-with-openapi.md) | A docs page for your API, made from your routes, DTOs and models. |
| [Docker](docker.md) | A small production image, Postgres in Docker Compose, env and a health check. |
| [Deploy to a Linux server](deploy-vps.md) | Your own server with systemd, and Caddy in front for HTTPS. |
| [Deploy to Fly.io](deploy-fly.md) | Fly.io from your `Dockerfile`, with SQLite on a volume or with Postgres. |
| [Deploy to Google Cloud Run](deploy-cloud-run.md) | Cloud Run from your `Dockerfile`, with Cloud SQL and Secret Manager. |

Most guides use the app that `dox create my_app` makes. The package name is `my_app`.
Change it to your own package name in the imports.
The OpenAPI guide and the deploy guides use the blog API of the [tutorial](../tutorial/01-create-project.md). Its package name is `blog`.

The code of the app guides is in one app on GitHub: [examples/guides](https://github.com/dartondox/dox/tree/main/examples/guides).
The blog API is in [examples/blog-api](https://github.com/dartondox/dox/tree/main/examples/blog-api).
CI builds both and runs their tests on every push, so the code on these pages keeps working.

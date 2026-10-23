# Guides

Each guide solves one job from start to end. Copy the files, run the commands, and check the result.
The reference pages explain each part in more detail. The guides link to them.

The code of all guides is in one app on GitHub: [examples/guides](https://github.com/dartondox/dox/tree/develop/examples/guides).
CI builds it and runs its tests on every push, so the code on these pages keeps working.

| Guide | What you get |
| --- | --- |
| [File upload](file-upload.md) | Accept an image, check its size and type, save it, return its URL. |
| [Pagination](pagination.md) | A list route with `page` and `per_page`, and the JSON shape it returns. |
| [JWT authentication](jwt-auth.md) | Register, log in, protect routes, read the user, log out. |
| [Custom errors](custom-errors.md) | Your own exception classes, one JSON shape for every error, logging. |
| [Background work](background-work.md) | Run work after the response, use another thread for CPU work, run a timer. |
| [Docker](docker.md) | A small production image with `dox build`, Postgres, env and a health check. |
| [Testing with a database](testing-with-database.md) | Tests on SQLite or a test Postgres, with migrations and cleanup. |
| [Static files and SPA](static-files.md) | Serve a folder or a single page app, with cache headers. |
| [CORS for a browser front-end](cors-for-spa.md) | The CORS setup that works with a React, Vue or Flutter web app. |
| [Environments](environments.md) | Dev, staging and production config, `.env` files, secrets and `APP_KEY`. |

All guides use the app that `dox create my_app` makes. The package name is `my_app`.
Change it to your own package name in the imports.

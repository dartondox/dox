# Blog API example

This is the finished app of the [Build a blog API](../../docs/tutorial/index.md) tutorial.
Dox is a new web framework for Dart. This app shows a small JSON API built with it:
posts, validation with `@Dto` classes, and JWT login with `dox_auth`.

It belongs to these docs pages:

- [Step 1: Create the project](../../docs/tutorial/01-create-project.md)
- [Step 2: Model and migration](../../docs/tutorial/02-model-and-migration.md)
- [Step 3: Routes and controller](../../docs/tutorial/03-routes-and-controller.md)
- [Step 4: Validation](../../docs/tutorial/04-validation.md)
- [Step 5: Login with dox_auth](../../docs/tutorial/05-auth.md)
- [Step 6: Test](../../docs/tutorial/06-test.md)
- [Step 7: Build and deploy](../../docs/tutorial/07-build-and-deploy.md)

The app uses the Dox packages of this repo, not the ones on pub.dev.
`pubspec_overrides.yaml` points to them.

## Run the tests

The app uses SQLite. You need no database server and no Docker.

```bash
cp .env.example .env
dart pub get
dox key:generate   # needs the dox CLI: dart pub global activate dox ^3.0.0-rc
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
dart test --concurrency=1
```

`.env.example` has an empty `APP_KEY`. `key:generate` puts a new key in `.env`.

The tests start the app on `APP_PORT` (3000) and call its routes.
`test/http_test.dart` is the test of step 6.
`test/api_test.dart` runs the `curl` checks of the other steps.

CI runs these steps on every push, so the code of the tutorial keeps working.

## Run the app

```bash
dart run bin/server.dart
curl http://localhost:3000/api/ping
```

The app has the same layout as a new `dox create` project.
It also has the queue (`bin/queue.dart`), the scheduler (`bin/schedule.dart`)
and the seeders (`bin/seed.dart`, `db/seeders/`). The tutorial does not change them.

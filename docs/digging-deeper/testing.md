# Testing

This page shows how to test a Dox app with the `test` package: HTTP routes, cache, storage, env and the database.

## Setup

Add the test packages as dev dependencies:

```bash
dart pub add dev:test dev:http
```

Put your tests in the `test/` folder. Run them with:

```bash
dart test
```

## Test HTTP routes

Start the real server once for the whole file. Then send requests to it with `package:http`.

```dart title="test/http_test.dart"
import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/config/app.dart';
import 'package:test/test.dart';

String baseUrl = 'http://localhost:${appConfig.serverPort}';

void main() {
  setUpAll(() async {
    Dox().initialize(appConfig);
    Dox().totalIsolate(1);
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  test('GET /api/ping', () async {
    http.Response response = await http.get(Uri.parse('$baseUrl/api/ping'));
    expect(response.statusCode, 200);
    expect(response.body, 'pong');
  });
}
```

- `startServer()` returns when the server listens. You do not need to wait after it.
- `Dox().totalIsolate(1)` runs the server on one isolate. By default Dox starts one isolate per CPU core. A test does not need them, and they make the start slower.
- With one isolate, you can also add a route inside a test with `Route.get(...)`. It works right away.
- Do not run `dox serve` on the same port while you test. The test can fail to start, or send its requests to the dev server. Stop `dox serve`, or use another `APP_PORT` for tests.

## Test the cache

`Dox().cache` is the `CacheManager` that `Cache()` uses. Replace it with a memory store, so tests do not write files or need Redis:

```dart
setUp(() {
  Dox().cache = CacheManager(CacheConfig(
    defaultStore: 'memory',
    stores: <String, Map<String, dynamic>>{
      'memory': <String, dynamic>{'driver': 'memory'},
    },
  ));
});

test('caches the posts', () async {
  await Cache().put('posts', <String>['a', 'b']);
  expect(await Cache().get('posts'), <dynamic>['a', 'b']);
});
```

A new `CacheManager` in `setUp` gives each test an empty cache. See [Cache](cache.md).

## Test file storage

`Dox().storage.fake(name)` swaps one disk with an empty memory disk. `restore(name)` puts the real disk back.

```dart
setUpAll(() {
  Dox().initialize(appConfig);
});

test('saves the report', () async {
  Disk fake = Dox().storage.fake('s3');

  String path = await Storage()
      .disk('s3')
      .put('reports', <int>[1, 2, 3], extension: 'pdf'); // '/reports/<uuid>.pdf'

  expect(await fake.exists(path.substring(1)), isTrue);
  Dox().storage.restore('s3');
});
```

- Call `Dox().initialize()` first. The storage disks are made from `appConfig`.
- `Storage()` paths start with `/`. A `Disk` key does not, so remove the first `/` when you ask the `Disk` directly.

See [File Storage](file-storage.md).

## Test the env

Pass your own values to `AppEnv.load()`. Then nothing is read from the shell or the `.env` file:

```dart
AppEnv env = AppEnv.load(
  EnvReader(
    environment: <String, String>{'APP_KEY': 'test'},
    dotEnv: <String, String>{'DB_PORT': '5433'},
  ),
);
expect(env.dbPort, 5433);
```

A missing or bad key throws an `EnvException`. So you can also test that your app stops on a bad env. See [Environment Variables](env.md).

## Test the database

A test that uses models needs a real database. Run the migrations and the ORM service once, before the tests:

```dart title="test/db_test.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:my_app/app/models/user/user.model.dart';
import 'package:my_app/config/app.dart';
import 'package:my_app/config/database.dart';
import 'package:my_app/services/orm_service.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    Dox().initialize(appConfig);
    await Migrator(
      connection: await databaseConfig
          .getConnectionConfig()
          .getDatabaseConnection(),
    ).migrate();
    await ORMService().setup();
  });

  test('saves a user', () async {
    User user = User()
      ..name = 'Dox'
      ..email = 'test-${DateTime.now().microsecondsSinceEpoch}@dox.dev'
      ..password = 'secret';
    await user.save();
    expect(user.id, isNotNull);
  });
}
```

- Use a separate test database. Set its name in the env of the test run, for example `DB_NAME=app_test dart test`.
- Make each test data unique (like the email above), or delete it at the end of the test. Then tests do not break each other.
- `ORMService().setup()` runs the same code as at server start. See [Services](services.md).

!!! tip "Run test files one by one"
    `dart test` runs test files at the same time. When two files start the server on the same port, or use the same tables, run them one by one: `dart test --concurrency=1`.

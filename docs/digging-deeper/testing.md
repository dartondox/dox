---
icon: lucide/test-tube
---

# Testing

This page shows how to test a Dox app with the `test` package: HTTP routes, cache, storage, env and the database.

## Setup

Add the test package as a dev dependency:

```bash
dart pub add dev:test
```

Put your tests in the `test/` folder. Run them with:

```bash
dart test
```

## Test HTTP routes

`DoxTestClient` from `package:dox_core/testing.dart` starts your app inside the test and sends requests to it.

```dart title="test/http_test.dart"
import 'package:dox_core/testing.dart';
import 'package:my_app/config/app.dart';
import 'package:test/test.dart';

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(appConfig);
  });

  tearDownAll(() async {
    await client.close();
  });

  test('GET /api/ping', () async {
    TestResponse res = await client.get('/api/ping');
    res.expectStatus(200).expectBody('pong');
  });

  test('POST /api/posts', () async {
    TestResponse res = await client.post(
      '/api/posts',
      body: <String, dynamic>{'title': 'Hello', 'body': 'My first post.'},
    );
    res.expectStatus(201).expectJson(containsPair('title', 'Hello'));
  });
}
```

- `DoxTestClient.start(appConfig)` runs your services (like the ORM service) and adds your routes, the same as a real start.
- It listens on `127.0.0.1` and a free port that the OS picks. So it does not clash with `dox serve`, and many test files can run at the same time.
- It runs on one isolate. `serverPort` and `totalIsolate` of the config are not used.
- `client.close()` stops the server and runs the `DoxShutdown` services (for example, it closes the database).
- With one isolate, you can also add a route inside a test with `Route.get(...)`. It works right away.

### Send requests

| Method | What it does |
| --- | --- |
| `get(path)` | `GET`. The path can have a query: `'/api/users?page=2'`. |
| `post(path, body: ...)` | `POST`. Also `put`, `patch` and `delete`. |
| `send('OPTIONS', path)` | any other method |
| `headers: {...}` | extra headers for one request |
| `withHeaders({...})` | a copy of the client that sends these headers on every request |
| `withToken(token)` | a copy of the client that sends `Authorization: Bearer <token>` |

A `Map` or `List` body is sent as JSON. A `String` or `List<int>` body is sent as it is.
Redirects are not followed, so you can check a `302` and its `Location` header.

### Check the response

| Member | What it gives |
| --- | --- |
| `res.status` | the status code, like `200` |
| `res.body` | the body as text |
| `res.json` | the body read as JSON |
| `res.header('content-type')` | one header (any case) |
| `res.headers` | all headers, with lower case names |

The `expect` methods fail the test when the response is not right. They return the response, so you can chain them:

```dart
res
    .expectStatus(422)
    .expectHeader('content-type', contains('application/json'))
    .expectJson(<String, dynamic>{'title': 'The title is required'});
```

| Method | Fails when |
| --- | --- |
| `expectStatus(200)` | the status is another one. The message shows the body. |
| `expectJson(value or matcher)` | the JSON body does not match. Use a `Map`, or a matcher like `containsPair('id', 1)`. |
| `expectBody(value or matcher)` | the text body does not match |
| `expectHeader(name, value or matcher)` | the header does not match. Use `isNull` for "not there". |

### Log in as a user

Make a token, then send it with `withToken`:

```dart
TestResponse login = await client.post(
  '/api/auth/login',
  body: <String, dynamic>{'email': 'ann@example.com', 'password': 'secret123'},
);
DoxTestClient ann = client.withToken(login.json['token'] as String);
(await ann.get('/api/auth/me')).expectStatus(200);
```

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

`Storage.manager.fake(name)` (from `dox_storage`) swaps one disk with an empty memory disk. `restore(name)` puts the real disk back.

```dart
setUpAll(() {
  Dox().initialize(appConfig);
});

test('saves the report', () async {
  Disk fake = Storage.manager.fake('s3');

  String path = await Storage()
      .disk('s3')
      .put('reports', <int>[1, 2, 3], extension: 'pdf'); // '/reports/<uuid>.pdf'

  expect(await fake.exists(path.substring(1)), isTrue);
  Storage.manager.restore('s3');
});
```

- Call `Dox().initialize()` first. Without the `StorageService` running, `Storage.manager` has only the `local` disk. Start the app, or set the disks yourself: `Storage.manager = StorageDiskFactory().create(storageConfig);`.
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

A test that uses models needs a real database. Run the migrations once in `setUpAll`.
Then empty the tables before each test with `refreshDatabase()` from `package:dox_orm/testing.dart`:

```dart title="test/user_test.dart"
import 'package:dox_core/testing.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:dox_orm/testing.dart';
import 'package:my_app/config/app.dart';
import 'package:my_app/config/database.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
    client = await DoxTestClient.start(appConfig); // runs the ORM service
  });

  // every test starts with empty tables
  setUp(refreshDatabase);

  tearDownAll(() async {
    await client.close();
  });

  test('register makes a user', () async {
    TestResponse res = await client.post(
      '/api/auth/register',
      body: <String, dynamic>{
        'name': 'Ann',
        'email': 'ann@example.com',
        'password': 'secret123',
      },
    );
    res.expectStatus(201);
  });
}
```

- `refreshDatabase()` empties every table and starts the ids at 1 again. The tables stay. It keeps the rows of the migrations table (`dox_db_migration`).
- It works on Postgres, MySQL, MariaDB and SQLite. Foreign keys are not checked while it empties the tables.
- `refreshDatabase(keep: <String>['dox_db_migration', 'countries'])` keeps the rows of more tables.
- Use a separate test database. Set its name in the env of the test run, for example `DB_NAME=app_test dart test`. Never run it on a database with real data.
- A test without the server can start the ORM with `SqlQueryBuilder.initializeWithDatabaseConfig(databaseConfig)`.

See [Testing with a database](../guides/testing-with-database.md) for a full example with SQLite.

!!! tip "Run test files one by one"
    `dart test` runs test files at the same time. When two files use the same tables, run them one by one: `dart test --concurrency=1`.

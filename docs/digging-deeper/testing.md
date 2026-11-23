---
icon: lucide/test-tube
---

# Testing

This page shows how to test a Dox app with the `test` package: HTTP routes, cache, storage, env and the database.

## Setup

A new app from `dox create` already has the `test` package. In another app, add it as a dev dependency:

```bash
dart pub add dev:test
```

Put your tests in the `test/` folder and run them:

```bash
dart test
```

### Creating a test

`dox make:test` writes `test/ping_test.dart`, which starts the app with a `DoxTestClient`. Add `--unit` for a plain test with no app:

```bash
dox make:test Ping
```

See [`dox make:test`](../reference/cli.md#dox-maketest).

## Test HTTP routes

`DoxTestClient` from `package:dox_core/testing.dart` starts your app inside the test and sends requests to it. Start it in `setUpAll` and close it in `tearDownAll`:

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
}
```

`start` runs your providers and adds your routes, like a real start. It uses one isolate on `127.0.0.1` and a free port. `close` stops the server and runs `shutdown()` of every provider.

### Making requests

The client has `get`, `post`, `put`, `patch` and `delete`. Use `send` for any other method:

```dart
await client.get('/api/users?page=2');
await client.post('/api/posts',
    body: <String, dynamic>{'title': 'Hello'});
await client.send('OPTIONS', '/api/users');
```

A map or list body goes as JSON. A string or byte list body goes as it is. The client does not follow redirects, so you can check a 302 and its `Location` header.

### Sending headers

Pass `headers` for one request. `withHeaders` gives a copy of the client that sends the headers with each request:

```dart
await client.get('/api/me',
    headers: <String, String>{'Accept-Language': 'de'});

DoxTestClient german =
    client.withHeaders(<String, String>{'Accept-Language': 'de'});
```

### Log in as a user

`withToken` gives a copy of the client that sends `Authorization: Bearer <token>`:

```dart
TestResponse login = await client.post(
  '/api/auth/login',
  body: <String, dynamic>{'email': 'ann@example.com', 'password': 'secret'},
);
DoxTestClient ann = client.withToken(login.json['token'] as String);
(await ann.get('/api/auth/me')).expectStatus(200);
```

### Keep a session (cookies and CSRF)

`withSession` gives a client that works like a browser. It keeps the cookies of each response and sends the CSRF token on POST, PUT, PATCH and DELETE:

```dart
test('log in with a form', () async {
  DoxTestClient browser = client.withSession();

  // the first page gives the session and XSRF-TOKEN cookies
  (await browser.get('/login')).expectStatus(200);

  (await browser.post(
    '/login',
    body: <String, dynamic>{'email': 'ann@example.com', 'password': 's3'},
  )).expectStatus(303).expectHeader('location', '/dashboard');

  (await browser.get('/dashboard')).expectStatus(200);
});
```

`browser.cookies` has the kept cookies, and you can change them. The normal client keeps no cookies. To send the cookies of one response, use `withCookies(res.cookies)`.

### Testing a server that runs

Give the URL of a running server to the constructor. `baseUri` and `headers` show the URL and the headers of a client:

```dart
DoxTestClient client = DoxTestClient(Uri.parse('http://127.0.0.1:3000'));
```

## Checking the response

A `TestResponse` has the status, the body, the headers and the cookies:

```dart
int status = res.status;
String body = res.body;
List<int> bytes = res.bodyBytes;
dynamic json = res.json; // the body read as JSON
String? type = res.header('content-type'); // any case
Map<String, String> cookies = res.cookies;
```

`res.headers` has all headers, with lower case names.

### Expect methods

Each `expect` method fails the test when the response is not right. It returns the response, so you can chain them:

```dart
res
    .expectStatus(422)
    .expectHeader('content-type', contains('application/json'))
    .expectJson(<String, dynamic>{'title': 'The title is required'});
```

- `expectStatus(code)`: the failure message shows the body.
- `expectJson(value)`: a value or a matcher, like `containsPair('id', 1)`.
- `expectBody(value)`: the body as text.
- `expectHeader(name, value)`: use `isNull` for a header that must be missing.

## Test the cache

Replace `Dox().cache` with a memory store in `setUp`. `Cache()` then uses it, and each test starts with an empty cache:

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

See [Cache](cache.md).

## Test file storage

`Storage.manager.fake(name)` from `dox_storage` puts an empty memory disk in place of one disk. `restore(name)` puts the real disk back:

```dart
setUpAll(() {
  Dox().initialize(appConfig);
});

test('saves the report', () async {
  Disk fake = Storage.manager.fake('s3');

  String path = await Storage()
      .disk('s3')
      .putFile('reports', <int>[1, 2, 3], extension: 'pdf');

  expect(await fake.exists(path.substring(1)), isTrue);
  Storage.manager.restore('s3');
});
```

Call `Dox().initialize()` first, or `Storage.manager` has only the `local` disk. A `Storage()` path starts with `/` and a `Disk` key does not, so remove the first `/`.

`assertExists(key)` and `assertMissing(key)` of a disk throw a `StateError` when the check fails:

```dart
await fake.assertExists('reports/a.pdf');
```

See [File Storage](file-storage.md).

## Use a test database with `.env.testing`

Put the values for tests in a `.env.testing` file, next to `.env`:

```ini title=".env.testing"
DB_NAME=my_app_test
CACHE_STORE=memory
```

In tests (`dart test`, or `APP_ENV=testing`), Dox reads `.env` and then `.env.testing`. A key in `.env.testing` wins, and a real environment variable wins over both files.

## Test the database

Run the migrations one time in `setUpAll`. `refreshDatabase()` from `package:dox_orm/testing.dart` empties the tables before each test:

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
    client = await DoxTestClient.start(appConfig); // runs the ORM provider
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

`refreshDatabase()` empties every table and starts the ids at 1 again. It keeps the tables and the rows of the `dox_db_migration` table.

!!! warning
    `refreshDatabase()` deletes all rows. Use a separate test database, set in [`.env.testing`](#use-a-test-database-with-envtesting).

### Keeping some tables

Pass the tables that every test needs in `keep`:

```dart
refreshDatabase(keep: <String>['dox_db_migration', 'countries']);
```

See [Testing with a database](../guides/testing-with-database.md) for a full example with SQLite.

### Running test files one by one

`dart test` runs test files at the same time. When two files use the same tables, run them one by one:

```bash
dart test --concurrency=1
```

## Test the env

Give your own values to `AppEnv.load()`. Then it reads nothing from the shell or the `.env` file:

```dart
AppEnv env = AppEnv.load(
  EnvReader(
    environment: <String, String>{'APP_KEY': 'test'},
    dotEnv: <String, String>{'DB_PORT': '5433'},
  ),
);
expect(env.dbPort, 5433);
```

A missing or bad key throws an `EnvException`. A getter default that calls `Env.get()` reads the real env, so use other getters in a default. See [Environment Variables](env.md).

## Next steps

- [Testing with a database](../guides/testing-with-database.md): a full example with SQLite.
- [Cache](cache.md): the cache stores.
- [File Storage](file-storage.md): the disks.

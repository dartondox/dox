---
icon: lucide/flask-conical
---

# Step 6: Test

This step writes one HTTP test for the list route and runs it.

## 1. Write the test

The template has `test/http_test.dart`. Replace it with this:

```dart title="test/http_test.dart"
import 'package:blog/config/app.dart';
import 'package:blog/config/database.dart';
import 'package:dox_core/testing.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

void main() {
  late DoxTestClient client;

  setUpAll(() async {
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
    client = await DoxTestClient.start(appConfig);
  });

  tearDownAll(() async {
    await client.close();
  });

  test('GET /api/posts gives a list', () async {
    TestResponse res = await client.get('/api/posts');
    res.expectStatus(200).expectJson(isA<List<dynamic>>());
  });
}
```

- `DoxTestClient.start` runs the app inside the test, on a free port. It does not clash with `dox s`.
- It runs the migrations first, so the test also works on an empty database.
- `package:test` is already in `dev_dependencies` of the template.

## Check it

```bash
dart test test/http_test.dart
```

```text
00:01 +1: All tests passed!
```

!!! tip "Use another database for tests"
    The test uses the `.env` file, so it reads and writes `db/dox.sqlite`.
    To keep test data out of it, make a `.env.testing` file with `DB_NAME=test.sqlite`.
    `dart test` reads it on top of `.env`.

## Next

[Step 7: Build and deploy](07-build-and-deploy.md)

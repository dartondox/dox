---
icon: lucide/flask-conical
---

# Step 6: Test

In this step you write one HTTP test for the list route and run it.

## 1. Write the test

A test calls your routes like a real client. Replace the template's `test/http_test.dart` with this:

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

`DoxTestClient.start` runs the app in the test on a free port. The test runs the migrations first, so it also works on an empty database.

## Check it

Run the test:

```bash
dart test test/http_test.dart
```

You see:

```text
00:01 +1: All tests passed!
```

The test reads `.env`, so it uses your dev database. To use another database, make a `.env.testing` file with `DB_NAME=test.sqlite`. The test reads it on top of `.env`.

## Next steps

- [Step 7: Build and deploy](07-build-and-deploy.md): make a native binary and a Docker image.

# Step 6: Test

This step writes one HTTP test for the list route and runs it.

## 1. Write the test

The template has `test/http_test.dart`. Replace it with this:

```dart title="test/http_test.dart"
import 'dart:convert';

import 'package:blog/config/app.dart';
import 'package:blog/config/database.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../db/migration/migrations.dart';

String baseUrl = 'http://localhost:${appConfig.serverPort}';

void main() {
  setUpAll(() async {
    Dox().initialize(appConfig);
    Dox().totalIsolate(1);
    await Migrator(
      migrations: migrations,
      config: databaseConfig.getConnectionConfig(),
    ).migrate();
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  test('GET /api/posts gives a list', () async {
    http.Response response = await http.get(Uri.parse('$baseUrl/api/posts'));
    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), isA<List<dynamic>>());
  });
}
```

- The test starts the real server once, on one isolate. One isolate starts faster.
- It runs the migrations first, so the test also works on an empty database.
- `package:test` and `package:http` are already in `dev_dependencies` of the template.

## 2. Stop the dev server

The test listens on the same port as `dox s`. Stop `dox s` with `Ctrl+C` first.

## Check it

```bash
dart test test/http_test.dart
```

```text
00:01 +1: All tests passed!
```

!!! tip "Use another database for tests"
    The test uses the `.env` file, so it reads and writes `db/dox.sqlite`.
    To keep test data out of it, set another file for the test run:
    `DB_NAME=test.sqlite dart test test/http_test.dart`.

## Next

[Step 7: Build and deploy](07-build-and-deploy.md)

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

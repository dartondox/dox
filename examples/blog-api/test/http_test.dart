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
      connection: await databaseConfig
          .getConnectionConfig()
          .getDatabaseConnection(),
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

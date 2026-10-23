import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';
import 'package:my_app/config/app.dart';
import 'package:my_app/config/database.dart';

import '../db/migration/migrations.dart';

void main() async {
  Dox().initialize(appConfig);

  await Migrator(
    migrations: migrations,
    connection: await databaseConfig
        .getConnectionConfig()
        .getDatabaseConnection(),
  ).migrate();

  await Dox().startServer();
}

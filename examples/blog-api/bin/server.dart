import 'package:blog/config/app.dart';
import 'package:blog/config/database.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';

import '../db/migration/migrations.dart';

void main() async {
  /// Initialize Dox
  Dox().initialize(appConfig);

  /// Run the migrations from db/migration/migrations.dart once, before
  /// the server starts. We pass the config from config/database.dart,
  /// so this also works with env variables and no `.env` file.
  await Migrator(
    migrations: migrations,
    config: databaseConfig.getConnectionConfig(),
  ).migrate();

  /// Start dox http server
  await Dox().startServer();
}

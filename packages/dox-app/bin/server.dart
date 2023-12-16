import 'package:dox_app/config/app.dart';
import 'package:dox_app/config/postgres.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_migration/dox_migration.dart';

void main() async {
  /// Initialize Dox
  Dox().initialize(appConfig);

  /// Run database migration before starting server.
  /// Since Migration need to process only once,
  /// it do not required to register in services.
  await Migration().migrate(postgresEndpoint);

  /// Start dox http server
  await Dox().startServer();
}

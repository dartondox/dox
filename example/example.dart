import 'package:dox_core/dox_core.dart';

import '../test/integration/requirements/config/app.dart';

void main() async {
  /// Initialize Dox
  Dox().initialize(Config());

  /// add database connection to isolate if required
  /// Dox().addService(Database());

  /// set total thread
  Dox().totalIsolate(6);

  /// run database migration before starting server
  /// running migration should not be on part of Dox services
  /// await Database().migrate();

  /// start dox http server
  await Dox().startServer();
}

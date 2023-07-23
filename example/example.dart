import 'package:dox_core/dox_core.dart';

import '../test/integration/requirements/config/app.dart';
import 'config/database.dart';
import 'config/redis.dart';

void main() async {
  /// Initialize Dox
  Dox().initialize(Config());

  /// add database connection to isolate if required
  Dox().addService(Database());

  /// add database connection to isolate if required
  Dox().addService(Redis());

  /// set total thread
  Dox().totalIsolate(3);

  /// run database migration before starting server
  /// running migration should not be on part of Dox services
  await Database().migrate();

  /// start dox http server
  await Dox().startServer();
}

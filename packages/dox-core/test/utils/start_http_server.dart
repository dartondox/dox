import 'package:dox_core/dox_core.dart';

import '../integration/requirements/config/app.dart';

Future<void> startHttpServer(Config config) async {
  Dox().initialize(config);
  await Dox().startServer();
}

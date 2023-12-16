import 'package:dox_core/dox_core.dart';

import '../middleware/custom_middleware.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  void register() {
    Route.use(customMiddleware);
    Route.use(<IDoxMiddleware>[ClassBasedMiddleware()]);

    Route.get('ping', (DoxRequest req) => 'pong');
  }
}

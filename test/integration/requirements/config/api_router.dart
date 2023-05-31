import 'package:dox_core/dox_core.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  register() {
    Route.get('ping', (req) => 'pong');
  }
}

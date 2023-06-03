import 'package:dox_core/dox_core.dart';

class ApiRouter extends Router {
  @override
  String get prefix => 'api';

  @override
  void register() {
    Route.get('ping', (DoxRequest req) => 'pong');
  }
}

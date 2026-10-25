import 'package:dox_core/dox_core.dart';

@Inject()
class ApiController {
  /// Health check
  @Summary('Ping')
  @Tags(<String>['Health'])
  String pong(DoxRequest req) {
    return 'pong';
  }
}

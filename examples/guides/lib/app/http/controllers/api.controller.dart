import 'package:dox_core/dox_core.dart';

@Inject()
class ApiController {
  String pong(DoxRequest req) {
    return 'pong';
  }
}

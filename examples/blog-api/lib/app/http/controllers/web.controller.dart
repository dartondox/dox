import 'package:dox_core/dox_core.dart';

@Inject()
class WebController {
  String pong(DoxRequest req) {
    return 'pong';
  }
}

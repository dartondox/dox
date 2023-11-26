import 'package:dox_core/dox_core.dart';

class CustomMiddleware extends DoxMiddleware {
  @override
  DoxRequest handle(DoxRequest req) {
    /// write your logic here
    return req;
  }
}

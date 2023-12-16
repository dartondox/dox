import 'package:dox_core/dox_core.dart';

class CustomMiddleware extends IDoxMiddleware {
  @override
  IDoxRequest handle(IDoxRequest req) {
    /// write your logic here
    return req;
  }
}

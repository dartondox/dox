import 'package:dox_core/dox_core.dart';

DoxRequest customMiddleware(DoxRequest req) {
  return req;
}

class ClassBasedMiddleware implements DoxMiddleware {
  @override
  DoxRequest handle(DoxRequest req) {
    return req;
  }
}

import 'package:dox_core/dox_core.dart';

DoxRequest customMiddleware(DoxRequest req) {
  return req;
}

class ClassBasedMiddleware implements IDoxMiddleware {
  @override
  IDoxRequest handle(IDoxRequest req) {
    return req;
  }
}

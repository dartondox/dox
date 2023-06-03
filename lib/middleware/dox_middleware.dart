import 'package:dox_core/request/dox_request.dart';

abstract class DoxMiddleware {
  dynamic handle(DoxRequest req);
}

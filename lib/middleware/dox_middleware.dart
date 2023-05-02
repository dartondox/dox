import 'package:dox_core/request/dox_request.dart';

abstract class DoxMiddleware {
  handle(DoxRequest req);
}

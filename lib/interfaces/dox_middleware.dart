/// coverage:ignore-file
import 'package:dox_core/dox_core.dart';

abstract class DoxMiddleware {
  dynamic handle(DoxRequest req);
}

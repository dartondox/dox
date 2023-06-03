import 'package:dox_core/dox_core.dart';

abstract class Handler {
  dynamic handle(DoxResponse res);
}

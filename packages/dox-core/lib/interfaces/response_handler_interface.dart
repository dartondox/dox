import 'package:dox_core/dox_core.dart';

abstract class ResponseHandlerInterface {
  const ResponseHandlerInterface();

  dynamic handle(DoxResponse res);
}

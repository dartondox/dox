import 'package:dox_core/dox_core.dart';

abstract class ResponseHandlerInterface {
  const ResponseHandlerInterface();

  DoxResponse handle(DoxResponse res);
}

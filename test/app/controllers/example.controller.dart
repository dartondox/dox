import 'package:dox_core/dox_core.dart';

class ExampleController {
  testException(DoxRequest req) {
    throw Exception('something went wrong');
  }

  httpException(DoxRequest req) {
    throw UnAuthorizedException();
  }
}

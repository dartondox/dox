import 'package:dox_core/dox_core.dart';

class ResponseHandler extends ResponseHandlerInterface {
  /// Modify the response here.
  /// Example
  /// ```
  /// return res.content(<String, String>{'foo' : 'bar'}).statusCode(200);
  /// ```
  @override
  DoxResponse handle(DoxResponse res) {
    return res;
  }
}

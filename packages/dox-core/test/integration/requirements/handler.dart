import 'package:dox_core/dox_core.dart';

class ResponseHandler extends ResponseHandlerInterface {
  @override
  DoxResponse handle(DoxResponse res) {
    /// mark errors, so tests can see this handler ran for them
    if (res.getContent() is IHttpException) {
      res.header('x-error-handled', 'yes');
    }
    return res;
  }
}

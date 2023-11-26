import 'package:dox_core/dox_core.dart';

class ResponseHandler extends ResponseHandlerInterface {
  @override
  dynamic handle(DoxResponse res) {
    if (res.content is IHttpException) {
      return <String, dynamic>{
        'code': res.content.code,
        'status': 'failed',
        'message': res.content.toResponse(),
      };
    }
  }
}

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  test('not_found_exception', () {
    NotFoundHttpException exception = NotFoundHttpException(
      message: '404 Not Found',
    );

    dynamic res = exception.toResponse();
    expect(res, <String, dynamic>{
      'code': 'not_found',
      'message': '404 Not Found',
    });
    expect(exception.code, 404);
  });

  test('a map message is sent as it is', () {
    Map<String, dynamic> body = <String, dynamic>{'error': 'gone'};
    expect(NotFoundHttpException().toResponse(), <String, dynamic>{
      'code': 'not_found',
      'message': 'Not Found',
    });
    IHttpException e = ValidationException(message: body);
    expect(e.toResponse(), body);
    expect(NotFoundHttpException(message: body).toResponse(), body);
  });
}

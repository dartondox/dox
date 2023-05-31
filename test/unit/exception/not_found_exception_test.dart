import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  test('not_found_exception', () {
    var exception = NotFoundHttpException(
      message: '404 Not Found',
      errorCode: 'not_found',
      code: 404,
    );

    var res = exception.toResponse();
    expect(res, '404 Not Found');
    expect(exception.code, 404);
  });
}

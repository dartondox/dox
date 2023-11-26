import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  test('not_found_exception', () {
    NotFoundHttpException exception = NotFoundHttpException(
      message: '404 Not Found',
    );

    dynamic res = exception.toResponse();
    expect(res, '404 Not Found');
    expect(exception.code, 404);
  });
}

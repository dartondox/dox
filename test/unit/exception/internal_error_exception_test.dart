import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  test('internal_error_exception', () {
    InternalErrorException exception = InternalErrorException(
      message: 'something went wrong',
      errorCode: 'internal_error',
    );

    dynamic res = exception.toResponse();
    expect(res, 'something went wrong');
    expect(exception.code, 500);
  });
}

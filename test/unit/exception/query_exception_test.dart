import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  test('query_exception', () {
    var exception = QueryException(
      message: 'Error in sql query',
      errorCode: 'sql_query_error',
      code: 500,
    );

    var res = exception.toResponse();
    expect(res, 'Error in sql query');
    expect(exception.code, 500);
  });
}

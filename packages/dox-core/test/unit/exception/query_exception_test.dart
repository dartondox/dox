import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  test('query_exception', () {
    QueryException exception = QueryException();

    dynamic res = exception.toResponse();
    expect(res, <String, dynamic>{
      'code': 'sql_query_error',
      'message': 'Error in sql query',
    });
    expect(exception.code, 500);
  });
}

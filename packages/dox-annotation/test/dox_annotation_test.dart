import 'package:dox_annotation/dox_annotation.dart';
import 'package:test/test.dart';

class TestException extends IHttpException {
  TestException(Object? text, {int status = 404, String error = 'not_found'}) {
    code = status;
    errorCode = error;
    message = text;
  }
}

class DefaultException extends IHttpException {}

void main() {
  group('IHttpException.toResponse', () {
    test('a text message gives code and message', () {
      expect(TestException('Not Found').toResponse(), <String, dynamic>{
        'code': 'not_found',
        'message': 'Not Found',
      });
    });

    test('a message that is not text is turned into text', () {
      expect(TestException(42, error: 'bad').toResponse(), <String, dynamic>{
        'code': 'bad',
        'message': '42',
      });
    });

    test('a Map message is sent as it is', () {
      Map<String, dynamic> errors = <String, dynamic>{
        'email': <String>['The email is required'],
      };
      expect(identical(TestException(errors).toResponse(), errors), isTrue);
    });

    test('the defaults are a server error', () {
      expect(DefaultException().toResponse(), <String, dynamic>{
        'code': 'server_error',
        'message': 'Server Error',
      });
    });
  });
}

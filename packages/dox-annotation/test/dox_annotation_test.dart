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

class BasicAuth implements IAuth {
  BasicAuth(this.loggedIn);
  final bool loggedIn;
  @override
  Future<void> verifyToken(IDoxRequest req) async {}
  @override
  bool isLoggedIn() => loggedIn;
  @override
  T? user<T>() => null;
  @override
  Map<String, dynamic>? toJson() => null;
}

class AuthWithId extends BasicAuth {
  AuthWithId() : super(true);
  int id() => 7;
}

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

  group('IAuth helpers', () {
    test('guest is the opposite of isLoggedIn', () {
      expect(BasicAuth(false).guest(), isTrue);
      expect(BasicAuth(true).guest(), isFalse);
    });

    test('id calls the id of the auth class', () {
      IAuth? auth = AuthWithId();
      expect(auth.id(), 7);
    });

    test('id is null when the auth class has no id', () {
      IAuth? auth = BasicAuth(true);
      expect(auth.id(), isNull);
    });
  });
}

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

class _Auth implements IAuthMiddleware {
  const _Auth({this.optional = false});

  final bool optional;

  @override
  IAuthMiddleware asOptional() => const _Auth(optional: true);

  @override
  dynamic handle(IDoxRequest req) => null;
}

void main() {
  test('an IAuthMiddleware is an IDoxMiddleware', () {
    IAuthMiddleware auth = const _Auth();
    expect(auth, isA<IDoxMiddleware>());
    expect((auth.asOptional() as _Auth).optional, isTrue);
  });
}

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('Hash |', () {
    test('make/verify', () {
      String secret = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';
      String hashedPassword = Hash.make(secret);
      bool result = Hash.verify(secret, hashedPassword);
      expect(result, true);
    });

    test('invalid should return false', () {
      String secret = '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt';
      String hashedPassword = Hash.make(secret);
      bool result = Hash.verify('password', hashedPassword);
      expect(result, false);
    });
  });
}

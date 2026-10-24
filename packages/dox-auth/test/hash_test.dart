import 'package:dox_auth/src/hash.dart';
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
    test('makeAsync/verifyAsync run bcrypt in another isolate', () async {
      String hashed = await Hash.makeAsync('secret');
      expect(await Hash.verifyAsync('secret', hashed), true);
      expect(await Hash.verifyAsync('wrong', hashed), false);
      expect(await Hash.verifyAsync('secret', 'not-a-hash'), false);
      expect(Hash.verify('secret', hashed), true);
    });

    test('rounds sets the bcrypt cost', () async {
      expect(Hash.make('secret', rounds: 4), startsWith(r'$2a$04$'));
      expect(await Hash.makeAsync('secret', rounds: 5), startsWith(r'$2a$05$'));
      expect(Hash.make('secret'), startsWith(r'$2a$10$'));
      Hash.rounds = 4;
      addTearDown(() => Hash.rounds = 10);
      String hashed = Hash.make('secret');
      expect(hashed, startsWith(r'$2a$04$'));
      expect(Hash.verify('secret', hashed), true);
    });
  });
}

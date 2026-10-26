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

    test('a malformed hash returns false', () {
      for (String bad in <String>['', 'abc', r'$2a$10$short']) {
        expect(Hash.verify('secret', bad), false);
      }
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

    test('a password over 72 bytes throws, and the error hides it', () async {
      String long = 'p' * 73;
      Matcher safe = isA<ArgumentError>()
          .having((ArgumentError e) => e.toString(), 'text', contains('72'))
          .having(
            (ArgumentError e) => e.toString(),
            'text',
            isNot(contains(long)),
          );
      expect(() => Hash.make(long, rounds: 4), throwsA(safe));
      await expectLater(Hash.makeAsync(long, rounds: 4), throwsA(safe));
      // 72 bytes is fine. 'é' is 2 bytes, so 37 of them is 74 bytes.
      expect(Hash.make('p' * 72, rounds: 4), startsWith(r'$2a$04$'));
      expect(() => Hash.make('é' * 37, rounds: 4), throwsA(safe));
    });
  });
}

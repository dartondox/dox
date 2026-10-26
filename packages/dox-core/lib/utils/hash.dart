import 'dart:convert';
import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';

class Hash {
  /// bcrypt cost (log rounds) for new hashes. Default: 10.
  /// Each step up doubles the time. Allowed: 4 to 31.
  /// Old hashes keep their own cost, so they still verify.
  /// ```
  /// Hash.rounds = 12;
  /// ```
  static int rounds = 10;

  /// bcrypt uses at most 72 bytes of a password.
  static const int maxBytes = 72;

  /// has the password using BCrypt technique.
  /// A password over [maxBytes] (72) bytes throws an [ArgumentError].
  /// The error text does not hold the password, so it is safe to log.
  /// Limit the length in your DTO, like `max(72)`.
  /// ```
  /// Hash.make('secret');
  /// Hash.make('secret', rounds: 12);
  /// ```
  static String make(String password, {int? rounds}) {
    _checkLength(password);
    int cost = rounds ?? Hash.rounds;
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: cost));
  }

  /// verify the password with input password and stored hash string.
  /// Returns false when the hash is not a valid bcrypt hash.
  /// ```
  /// Hash.verify('secret', '<hashedString>');
  /// ```
  static bool verify(String password, String hashedPassword) {
    try {
      return BCrypt.checkpw(password, hashedPassword);
    } catch (_) {
      return false;
    }
  }

  /// same as [make], but runs bcrypt in a new isolate,
  /// so the server can answer other requests in the meantime.
  /// ```
  /// String hash = await Hash.makeAsync('secret');
  /// ```
  static Future<String> makeAsync(String password, {int? rounds}) async {
    _checkLength(password);
    int cost = rounds ?? Hash.rounds;
    return Isolate.run(() {
      return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: cost));
    });
  }

  /// same as [verify], but runs bcrypt in a new isolate,
  /// so the server can answer other requests in the meantime.
  /// ```
  /// bool ok = await Hash.verifyAsync('secret', '<hashedString>');
  /// ```
  static Future<bool> verifyAsync(String password, String hashedPassword) {
    return Isolate.run(() => verify(password, hashedPassword));
  }

  /// true when [a] and [b] are the same. It takes the same time for
  /// any two values of the same length, so the time does not tell how
  /// much of a secret (an API key, a token) was right.
  /// ```
  /// if (!Hash.equals(req.header('X-Api-Key') ?? '', apiKey)) { ... }
  /// ```
  static bool equals(String a, String b) {
    List<int> x = utf8.encode(a);
    List<int> y = utf8.encode(b);
    if (x.length != y.length) return false;
    int diff = 0;
    for (int i = 0; i < x.length; i++) {
      diff |= x[i] ^ y[i];
    }
    return diff == 0;
  }

  /// bcrypt throws its own error with the password in the text. Throw
  /// first, with no password in the text, so logs never show it.
  static void _checkLength(String password) {
    if (utf8.encode(password).length > maxBytes) {
      throw ArgumentError(
        'The password is too long. bcrypt takes at most $maxBytes bytes.',
        'password',
      );
    }
  }
}

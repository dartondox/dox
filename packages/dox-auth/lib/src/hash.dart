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

  /// has the password using BCrypt technique
  /// ```
  /// Hash.make('secret');
  /// Hash.make('secret', rounds: 12);
  /// ```
  static String make(String password, {int? rounds}) {
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
  static Future<String> makeAsync(String password, {int? rounds}) {
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
}

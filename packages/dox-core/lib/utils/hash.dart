import 'package:bcrypt/bcrypt.dart';

class Hash {
  /// has the password using BCrypt technique
  /// ```
  /// Hash.make('secret');
  /// ```
  static String make(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
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
}

import 'package:bcrypt/bcrypt.dart';

class Hash {
  /// has the password using BCrypt technique
  /// ```
  /// Hash.make('secret');
  /// ```
  static String make(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// verity the password with input password and stored hash string
  /// ```
  /// Hash.verify('secret', '<hashedString>');
  /// ```
  static bool verify(String password, String hashedPassword) {
    return BCrypt.checkpw(password, hashedPassword);
  }
}

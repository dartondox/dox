import 'package:bcrypt/bcrypt.dart';

class Hash {
  static String make(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  static bool verify(password, hashedPassword) {
    return BCrypt.checkpw(password, hashedPassword);
  }
}

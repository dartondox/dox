import 'package:bcrypt/bcrypt.dart';
import 'package:dox_core/dox.dart';

class Hash {
  static String make(String password) {
    String secret = Dox().config.appKey;
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  static bool verify(password, hashedPassword) {
    return BCrypt.checkpw(password, hashedPassword);
  }
}

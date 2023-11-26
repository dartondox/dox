import 'package:dox_app/config/auth_config.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

class AuthService implements DoxService {
  @override
  void setup() {
    Auth.initialize(AuthConfig());
  }
}

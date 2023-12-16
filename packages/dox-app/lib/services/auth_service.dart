import 'package:dox_app/app/models/user/user.model.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

class AuthService implements DoxService {
  @override
  void setup() {
    Auth.initialize(AuthConfig(
      /// default auth guard
      defaultGuard: 'web',

      /// list of auth guards
      guards: <String, AuthGuard>{
        'web': AuthGuard(
          driver: JwtAuthDriver(secret: SecretKey(Env.get('APP_KEY'))),
          provider: AuthProvider(
            model: () => User(),
          ),
        ),
      },
    ));
  }
}

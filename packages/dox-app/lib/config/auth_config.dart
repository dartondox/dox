import 'package:dox_app/models/user/user.model.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

class AuthConfig extends IAuthConfig {
  @override
  String get defaultGuard => 'web';

  @override
  Map<String, AuthGuard> get guards => <String, AuthGuard>{
        'web': AuthGuard(
          driver: JwtAuthDriver(
            secret: SecretKey(Env.get('APP_KEY')),
          ),
          provider: AuthProvider(
            model: () => User(),
          ),
        ),
      };
}

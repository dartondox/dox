import 'package:dox_app/app/http/dtos/auth.dto.dart';
import 'package:dox_app/app/http/serializers/user.serializer.dart';
import 'package:dox_app/app/models/user/user.model.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

@Inject()
class AuthController {
  /// Log in
  ///
  /// Gives a bearer token for the `Authorization` header.
  Future<dynamic> login(LoginUser body) async {
    Map<String, dynamic> credentials = <String, dynamic>{
      'email': body.email,
      'password': body.password,
    };

    Auth auth = Auth();
    String? token = await auth.attempt(credentials);
    User? user = auth.user<User>();

    if (token != null) {
      return response(<String, dynamic>{
        'success': true,
        'token': token,
        'user': user,
      }).header('Authorization', token);
    }

    return <String, dynamic>{'success': false};
  }

  /// Make an account
  Future<User> register(RegisterUser body) async {
    User user = User();
    user.name = body.name;
    user.email = body.email;
    user.password = Hash.make(body.password);
    await user.save();
    return user;
  }

  /// The logged in user
  Future<dynamic> user(DoxRequest req) async {
    IAuth? auth = req.auth;
    if (auth?.isLoggedIn() == true) {
      Logger.info('${auth?.user<User>()?.name} is logged in');
      return UserSerializer(auth?.user());
    }
    return UnAuthorizedException();
  }
}

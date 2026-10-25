import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:my_app/app/http/dtos/login_user.dto.dart';
import 'package:my_app/app/http/dtos/register_user.dto.dart';
import 'package:my_app/app/models/user/user.model.dart';

@Inject()
class AuthController {
  /// POST /api/auth/register
  Future<Map<String, dynamic>> register(RegisterUser body) async {
    User user = User()
      ..name = body.name
      ..email = body.email
      ..password = Hash.make(body.password);
    await user.save();

    String? token = Auth().login(user);
    return <String, dynamic>{'token': token, 'user': user};
  }

  /// POST /api/auth/login
  Future<Map<String, dynamic>> login(LoginUser body) async {
    Auth auth = Auth();
    String? token = await auth.attempt(<String, dynamic>{
      'email': body.email,
      'password': body.password,
    });
    if (token == null) {
      throw UnAuthorizedException(message: 'Wrong email or password');
    }
    return <String, dynamic>{'token': token, 'user': auth.user<User>()};
  }

  /// GET /api/auth/me (behind AuthMiddleware)
  User? me(DoxRequest req) {
    return req.auth?.user<User>();
  }

  /// POST /api/auth/logout (behind AuthMiddleware)
  /// A JWT can not be cancelled on the server. The client deletes the
  /// token. The token still works until `expiresIn` passes.
  Map<String, String> logout(DoxRequest req) {
    return <String, String>{'message': 'Delete the token on the client'};
  }
}

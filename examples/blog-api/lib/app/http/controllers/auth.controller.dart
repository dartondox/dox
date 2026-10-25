import 'package:blog/app/http/dtos/login_user.dto.dart';
import 'package:blog/app/http/dtos/register_user.dto.dart';
import 'package:blog/app/models/user/user.model.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

@Inject()
class AuthController {
  /// POST /api/auth/register
  Future<DoxResponse> register(RegisterUser body) async {
    User user = User()
      ..name = body.name
      ..email = body.email
      ..password = Hash.make(body.password);
    await user.save();

    String? token = Auth().login(user);
    return response(<String, dynamic>{'token': token, 'user': user})
        .statusCode(201);
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

  /// GET /api/auth/user
  User? user(DoxRequest req) {
    return req.auth?.user<User>();
  }
}

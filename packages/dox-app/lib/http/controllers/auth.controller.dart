import 'package:dox_app/models/user/user.model.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

class AuthController {
  Future<dynamic> login(DoxRequest req) async {
    Map<String, dynamic> credentials = req.only(<String>['email', 'password']);

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

    return <String, dynamic>{
      'success': false,
    };
  }

  Future<dynamic> register(DoxRequest req) async {
    User user = User();
    user.debug(true);
    user.name = 'AJ';
    user.email = 'aj@mail.com';
    user.password = Hash.make('password');
    await user.save();
    return user;
  }

  Future<dynamic> user(DoxRequest req) async {
    if (req.auth?.isLoggedIn() == true) {
      return req.auth?.user();
    }
    throw UnAuthorizedException(message: 'reach to controller');
  }
}

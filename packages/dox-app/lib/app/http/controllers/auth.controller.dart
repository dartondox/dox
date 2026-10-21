import 'package:dox_app/app/http/dto/auth.dto.dart';
import 'package:dox_app/app/http/serializers/user.serializer.dart';
import 'package:dox_app/app/models/user/user.model.dart';
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/logger.dart';

class AuthController {
  /// Log in
  ///
  /// Gives a bearer token for the `Authorization` header.
  @Request(LoginUser)
  @Response(200, LoginResult)
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

    return <String, dynamic>{'success': false};
  }

  /// Make an account
  @Request(RegisterUser)
  Future<User> register(DoxRequest req) async {
    /// `unique` checks the database, so use validateAsync
    Map<String, dynamic> data = await req.validateAsync(<String, String>{
      'name': 'required|string',
      'email': 'required|email|unique:users,email',
      'password': 'required|min_length:8',
    });
    User user = User();
    user.name = data['name'];
    user.email = data['email'];
    user.password = Hash.make(data['password']);
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

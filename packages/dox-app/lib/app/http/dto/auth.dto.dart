import 'package:dox_app/app/models/user/user.model.dart';
import 'package:dox_core/dox_core.dart';

/// Data to make a new account.
@Dto()
class RegisterUser {
  @Length(min: 2, max: 100)
  final String name;

  @Email()
  final String email;

  @Length(min: 8)
  final String password;

  const RegisterUser({
    required this.name,
    required this.email,
    required this.password,
  });
}

/// Email and password to log in.
@Dto()
class LoginUser {
  @Email()
  final String email;

  final String password;

  const LoginUser({required this.email, required this.password});
}

/// Answer of a good login.
@Dto()
class LoginResult {
  final bool success;

  /// Bearer token for the `Authorization` header.
  final String token;

  final User user;

  const LoginResult({
    required this.success,
    required this.token,
    required this.user,
  });
}

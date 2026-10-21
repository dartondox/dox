import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart' hide Schema;

part 'auth.dto.g.dart';

/// Data to make a new account.
@Dto()
class RegisterUser {
  @Length(min: 2, max: 100)
  @Trim()
  final String name;

  @Trim()
  @Lowercase()
  @Email()
  @Unique('users', column: 'email')
  final String email;

  @MinLength(8)
  final String password;

  const RegisterUser({
    required this.name,
    required this.email,
    required this.password,
  });

  static const DtoSchema<RegisterUser> schema = $RegisterUserDto;
}

/// Email and password to log in.
@Dto()
class LoginUser {
  @Email()
  final String email;

  final String password;

  const LoginUser({required this.email, required this.password});

  static const DtoSchema<LoginUser> schema = $LoginUserDto;
}

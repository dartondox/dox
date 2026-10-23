import 'package:dox_orm/dox_orm.dart';

class AuthGuard {
  final AuthDriver driver;
  final AuthProvider provider;

  const AuthGuard({required this.driver, required this.provider});
}

class AuthProvider {
  final dynamic Function() model;

  final List<String> identifierFields;
  final String passwordField;

  const AuthProvider({
    required this.model,
    this.identifierFields = const <String>['email'],
    this.passwordField = 'password',
  });
}

class AuthConfig {
  final String defaultGuard;
  final Map<String, AuthGuard> guards;

  AuthConfig({
    required this.defaultGuard,
    this.guards = const <String, AuthGuard>{},
  });
}

/// A driver checks tokens and logins for a guard.
/// [guard] is the name of the guard in `AuthConfig.guards`.
/// Use `AuthEngine().guard(guard).provider` to get its user provider.
abstract class AuthDriver {
  Future<Model<dynamic>?> verifyToken(IDoxRequest req, String guard);

  Future<Model<dynamic>?> attempt(
    Map<String, dynamic> credentials,
    String guard,
  );

  String? createToken(Map<String, dynamic>? userPayload, String guard);
}

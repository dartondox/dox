import 'package:dox_query_builder/dox_query_builder.dart';

class AuthGuard {
  final AuthDriver driver;
  final AuthProvider provider;

  const AuthGuard({
    required this.driver,
    required this.provider,
  });
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

abstract class AuthDriver {
  Future<Model<dynamic>?> verifyToken(IDoxRequest req);

  Future<Model<dynamic>?> attempt(Map<String, dynamic> credentials);

  String? createToken(Map<String, dynamic>? userPayload);
}

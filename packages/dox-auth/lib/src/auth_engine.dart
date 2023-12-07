import 'package:dox_auth/src/interfaces.dart';

class AuthEngine {
  late AuthConfig config;

  /// get auth guard
  AuthGuard get guard => config.guards[config.defaultGuard]!;

  /// get driver
  AuthDriver get driver => guard.driver;

  /// get auth provider
  AuthProvider get provider => guard.provider;

  /// singleton
  static final AuthEngine _singleton = AuthEngine._internal();
  factory AuthEngine() => _singleton;
  AuthEngine._internal();

  void init(AuthConfig authConfig) {
    config = authConfig;
  }
}

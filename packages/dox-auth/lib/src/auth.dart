// ignore_for_file: depend_on_referenced_packages
import 'package:dox_auth/src/auth_engine.dart';
import 'package:dox_auth/src/interfaces.dart';
import 'package:dox_orm/dox_orm.dart';

class Auth implements IAuth {
  /// The guard name from `AuthConfig.guards`.
  /// null uses `AuthConfig.defaultGuard`.
  /// ```
  /// Auth(guard: 'admin').attempt(credentials);
  /// ```
  final String? guard;

  Auth({this.guard});

  /// user data
  Model<dynamic>? _userData;

  String get _guard => guard ?? AuthEngine().config.defaultGuard;

  AuthDriver get _driver => AuthEngine().guard(_guard).driver;

  static void initialize(AuthConfig authConfig) {
    AuthEngine().init(authConfig);
  }

  @override
  Future<void> verifyToken(IDoxRequest req) async {
    _userData = await _driver.verifyToken(req, _guard);
  }

  @override
  bool isLoggedIn() {
    return _userData != null;
  }

  @override
  T? user<T>() {
    return _userData as T?;
  }

  Future<String?> attempt(Map<String, dynamic> credentials) async {
    _userData = await _driver.attempt(credentials, _guard);
    return _createToken();
  }

  String? login(Model<dynamic> user) {
    _userData = user;
    return _createToken();
  }

  @override
  Map<String, dynamic>? toJson() {
    return _userData?.toJson();
  }

  String? _createToken() {
    if (_userData == null) {
      return null;
    }
    return _driver.createToken(_userData?.toJson(), _guard);
  }
}

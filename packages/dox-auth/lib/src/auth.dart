// ignore_for_file: depend_on_referenced_packages
import 'package:dox_auth/src/auth_engine.dart';
import 'package:dox_auth/src/interfaces.dart';
import 'package:dox_query_builder/dox_query_builder.dart';

class Auth implements IAuth {
  /// user data
  Model<dynamic>? _userData;

  AuthDriver get _driver => AuthEngine().driver;

  static void initialize(AuthConfig authConfig) {
    AuthEngine().init(authConfig);
  }

  @override
  Future<void> verifyToken(IDoxRequest req) async {
    _userData = await _driver.verifyToken(req);
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
    _userData = await _driver.attempt(credentials);
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
    return _driver.createToken(_userData?.toJson());
  }
}

// ignore_for_file: depend_on_referenced_packages
import 'package:dox_auth/src/auth_engine.dart';
import 'package:dox_auth/src/drivers/session_auth_driver.dart';
import 'package:dox_auth/src/interfaces.dart';
import 'package:dox_core/dox_core.dart';
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

  /// Set [user] as the logged-in user of [req], with no token and no
  /// password check. For your own auth middleware, like an API key check.
  /// `req.auth` then gives this user.
  /// ```
  /// Auth(guard: 'api').setUser(req, user);
  /// req.auth?.user<User>();
  /// ```
  void setUser(IDoxRequest req, Model<dynamic> user) {
    _userData = user;
    req.auth = this;
  }

  /// Check the credentials and keep the login in the session.
  /// true when it worked. Needs a guard with `SessionAuthDriver`.
  /// ```
  /// if (!await Auth().attemptSession(req, credentials)) {
  ///   req.session.flashErrors({'email': 'Wrong email or password'});
  ///   return back(req);
  /// }
  /// ```
  Future<bool> attemptSession(
    DoxRequest req,
    Map<String, dynamic> credentials,
  ) async {
    SessionAuthDriver driver = _sessionDriver;
    _userData = await driver.attempt(credentials, _guard);
    Model<dynamic>? user = _userData;
    if (user == null) return false;
    driver.login(req, user, _guard);
    return true;
  }

  /// Keep [user] in the session, with no password check.
  /// Needs a guard with `SessionAuthDriver`.
  void loginSession(DoxRequest req, Model<dynamic> user) {
    _userData = user;
    _sessionDriver.login(req, user, _guard);
  }

  /// End the session login. All session data is removed.
  void logout(DoxRequest req) {
    _userData = null;
    _sessionDriver.logout(req);
  }

  SessionAuthDriver get _sessionDriver {
    AuthDriver driver = _driver;
    if (driver is SessionAuthDriver) return driver;
    throw StateError(
      "The auth guard '$_guard' does not use SessionAuthDriver. "
      'Use attempt() and login() for a token.',
    );
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

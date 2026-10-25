// ignore_for_file: depend_on_referenced_packages
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';
import 'package:dox_orm/dox_orm.dart';

/// Keeps the login in the session (`req.session`), for web pages.
/// The browser sends the session cookie, so there is no token.
/// Needs `SessionMiddleware` on the route.
/// ```
/// AuthGuard(driver: SessionAuthDriver(), provider: AuthProvider(...));
///
/// bool ok = await Auth().attemptSession(req, credentials);
/// await Auth().logout(req);
/// ```
class SessionAuthDriver extends AuthDriver {
  /// bcrypt cost of the stored password hashes. Default: 10.
  final int hashRounds;

  SessionAuthDriver({this.hashRounds = 10}) {
    AuthDriver.prepareDummyHash(hashRounds);
  }

  /// The session key of the user id of [guard].
  static String sessionKey(String guard) => 'auth_$guard';

  /// The user of the id in the session, or null.
  @override
  Future<Model<dynamic>?> verifyToken(IDoxRequest req, String guard) async {
    dynamic id = (req as DoxRequest).session.get(sessionKey(guard));
    if (id == null) return null;
    Model<dynamic> model = AuthEngine().guard(guard).provider.model();
    return await model.find(id);
  }

  @override
  Future<Model<dynamic>?> attempt(
    Map<String, dynamic> credentials,
    String guard,
  ) {
    return AuthDriver.checkCredentials(credentials, guard, hashRounds);
  }

  /// There is no token. The session keeps the login.
  @override
  String? createToken(Map<String, dynamic>? userPayload, String guard) => null;

  /// Keep [user] in the session. The session gets a new id, so an id
  /// from before the login is no use (session fixation).
  void login(DoxRequest req, Model<dynamic> user, String guard) {
    Session session = req.session;
    session.regenerate();
    session.put(sessionKey(guard), user.toMap(original: true)[user.primaryKey]);
  }

  /// Remove the login and all session data. The session gets a new id.
  void logout(DoxRequest req) => req.session.invalidate();
}

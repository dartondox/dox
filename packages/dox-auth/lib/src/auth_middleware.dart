// ignore_for_file: depend_on_referenced_packages

import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/dox_core.dart';

class AuthMiddleware implements IDoxMiddleware {
  /// The guard name from `AuthConfig.guards`.
  /// null uses `AuthConfig.defaultGuard`.
  /// ```
  /// Route.get('/admin', <dynamic>[AuthMiddleware(guard: 'admin'), handler]);
  /// ```
  final String? guard;

  /// Send a guest to this page (like `/login`) instead of a 401.
  /// For web pages. null gives the 401.
  final String? redirectTo;

  AuthMiddleware({this.guard, this.redirectTo});

  @override
  Future<dynamic> handle(IDoxRequest req) async {
    Auth auth = Auth(guard: guard);

    // verify token from header and get user data from database
    await auth.verifyToken(req);

    if (auth.isLoggedIn()) {
      req.auth = auth;
      return req;
    }
    String? page = redirectTo;
    if (page != null) return redirect(page);
    throw UnAuthorizedException();
  }
}

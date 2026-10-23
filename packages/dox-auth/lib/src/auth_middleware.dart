// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: constant_identifier_names

import 'package:dox_auth/dox_auth.dart';
import 'package:dox_orm/dox_orm.dart';

const String AUTH_REQUEST_KEY = 'dox_authentication_instance';

class AuthMiddleware implements IDoxMiddleware {
  /// The guard name from `AuthConfig.guards`.
  /// null uses `AuthConfig.defaultGuard`.
  /// ```
  /// Route.get('/admin', <dynamic>[AuthMiddleware(guard: 'admin'), handler]);
  /// ```
  final String? guard;

  AuthMiddleware({this.guard});

  @override
  Future<IDoxRequest> handle(IDoxRequest req) async {
    Auth auth = Auth(guard: guard);

    // verify token from header and get user data from database
    await auth.verifyToken(req);

    if (auth.isLoggedIn()) {
      /// merge into request auth
      req.merge(<String, dynamic>{AUTH_REQUEST_KEY: auth});
      return req;
    }
    throw UnAuthorizedException();
  }
}
